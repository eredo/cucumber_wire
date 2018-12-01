import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:watcher/watcher.dart';
import 'package:path/path.dart' as p;

import 'message.dart';

/// Class which receives the dart file which contains the step definitions and
/// is responsible to spawn, restart and watch it. It's used as the proxy to
/// forward messages to the isolate.
class IsolateHandler implements Sink<WireMessage> {
  /// Stream to pass messages to the isolate.
  final _input = StreamController<WireMessage>.broadcast();

  /// Stream emits messages from the isolate.
  final _output = StreamController<WireMessage>.broadcast();

  /// Stream which emits whenever the isolate was restarted.
  final _start = StreamController<Null>.broadcast();

  /// Contains all the directory file watcher subscriptions, which are added
  /// when an isolate emits it's included files. When an isolate than sends
  /// a new list of files after a restart, the previous subscriptions are
  /// canceled.
  final _watchers = <StreamSubscription>[];

  /// Port which is sent to the isolate in order to receive messages.
  ReceivePort _receiverPort;

  final Uri path;

  /// Whether the IsolateHandler should listen for changes of the files used
  /// within the step definition file. When changes occur in the files the
  /// isolate will be restarted and a message will be emitted in [onStart].
  final bool watch;

  Isolate _isolate;

  /// Port which is received when the isolate starts. This is used to communicate
  /// to the isolate.
  SendPort _inputPort;

  /// Listener for forwarding messages from [_input.stream] to [_inputPort].
  StreamSubscription<List<int>> _inputListener;

  IsolateHandler(this.path, {this.watch = false}) {
    _startIsolate();
  }

  /// Stream which emits messages from the isolate. Emits errors when message
  /// parsing throws an exception.
  ///
  /// Notice: This stream may emit internal messages, therefore not all of the
  /// messages should be forwarded to the cucumber server.
  Stream<WireMessage> get onMessage => _output.stream;

  /// Stream which emits whenever the isolate was restarted. This occurs after
  /// a file that is included by the step definition has changed.
  Stream<Null> get onStart => _start.stream;

  /// Receives a new port for listening to messages. This getter also applies
  /// the necessary listener to emit messages and receive an input port.
  ReceivePort get _setupReceivePort {
    // Make sure to close previous port.
    _receiverPort?.close();

    _receiverPort = ReceivePort();
    _receiverPort.listen((msg) {
      if (msg is SendPort) {
        _inputPort = msg;
        _inputListener = _input.stream
            .map((m) => json.encode(m.encode()))
            .transform(utf8.encoder)
            .listen(_inputPort.send);
      }

      if (msg is List<int>) {
        try {
          final message = parse(utf8.decode(msg));
          if (message is InternalFileMessage) {
            _watchFiles(message.files);
          } else {
            _output.add(message);
          }
        } catch (ex, stackTrace) {
          _output.addError(ex, stackTrace);
        }
      }
    });

    return _receiverPort;
  }

  void _startIsolate() async {
    _isolate = await Isolate.spawnUri(path, [], _setupReceivePort.sendPort);
  }

  void _closeIsolate() {
    _inputListener.cancel();
    _receiverPort.close();
    _isolate.kill();
  }

  void _watchFiles(List<String> files) {
    _start.add(null);

    final directories = Set<String>.from(files.map(p.dirname));

    _watchers
      ..forEach((s) => s.cancel())
      ..clear()
      ..addAll(directories.map((dir) {
        return DirectoryWatcher(dir).events.listen((evt) {
          _closeIsolate();
          _startIsolate();
        });
      }));
  }

  @override
  void add(WireMessage data) => _input.add(data);

  @override
  void close() => _closeIsolate();
}
