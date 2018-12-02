import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cli_util/cli_logging.dart';

import 'configuration.dart';
import 'wire_server.dart';
import 'isolate_handler.dart';
import 'message.dart';

/// The bridge between the wire server that handles the connection of the
/// cucumber cli and the dart step definition file which is started in an
/// isolate.
/// The server is called by the `cucumber_wire` cli but can also be used using
/// the API. This can be necessary in the future for debugging purposes.
class Server {
  final _complete = Completer<void>();
  final Configuration configuration;
  Logger _logger;

  WireServer _server;
  IsolateHandler _isolate;

  StreamSubscription<Null> _isolateStartListener;
  StreamSubscription<ProcessSignal> _signalListener;

  Process _cucumberRunner;

  Server(this.configuration, {Logger logger}) {
    _server = WireServer(
      address: configuration.hostname,
      port: configuration.port,
    );

    _logger = logger ??
        (configuration.verbose ? Logger.verbose() : Logger.standard());
  }

  /// Starts the components of the server and completes when the step definition
  /// isolate is started successfully for the first time.
  Future<void> start() async {
    // Start the isolate and wait for a first successful start.
    _isolate = IsolateHandler(
      Uri.parse(configuration.entryPoint),
      watch: configuration.liveReload,
    );
    await _isolate.onStart.first;
    _logger.stdout('Step definitions loaded.');

    // Forward message from WireServer to IsolateHandler
    if (configuration.verbose) {
      _server.onMessage.listen(_logMessage('input'));
      _isolate.onMessage.listen(_logMessage('output'));
    }

    _server.onMessage.listen(_isolate.add, onError: (err, stack) {
      _logger.stderr('Error within wire server: $err\nStacktrace: $stack');
    });
    _isolate.onMessage.listen(_server.add, onError: (err, stack) {
      _logger.stderr('Error within isolate: $err\nStacktrace: $stack');
    });

    // Start the server.
    await _server.start();
    _logger.stdout('Server running: ${_server.address}:${_server.port}');

    if (configuration.runCucumber) {
      _isolateStartListener = _isolate.onStart.listen((_) => _runCucumber());
      _runCucumber();
    }
  }

  /// Stops the server including all components.
  Future<void> close() async {
    Exception ex;
    StackTrace trace;

    try {
      await _server.close();
    } catch (e, s) {
      ex = e;
      trace = s;
    }

    try {
      _isolate.close();

      await _isolateStartListener?.cancel();
      await _signalListener?.cancel();
    } catch (e, s) {
      ex = e;
      trace = s;
    }

    if (ex != null) {
      _complete.completeError(ex, trace);
    } else {
      _complete.complete();
    }
  }

  /// Fulfills when the server is closed, this may either occur when [close] is
  /// called or the server received a sigterm signal after using [bind] to listen
  /// for process signals.
  Future get complete => _complete.future;

  /// Binds the server to the process signals and detects sigterm to shutdown
  /// the serer.
  void bind() {
    _signalListener = ProcessSignal.sigterm.watch().listen((_) => close());
  }

  void _runCucumber() async {
    if (_cucumberRunner != null) {
      _logger.stdout('Stopping current cucumber execution.');
      _cucumberRunner.kill();
    }

    _cucumberRunner =
        await Process.start(configuration.cucumberExecutable, ['-f', 'pretty']);

    _cucumberRunner.stderr.listen(stderr.add);
    _cucumberRunner.stdout.listen(stdout.add);

    await _cucumberRunner.exitCode;
    _cucumberRunner = null;
  }

  void Function(WireMessage msg) _logMessage(String direction) {
    return (WireMessage msg) {
      _logger.trace('Message [$direction]: ${json.encode(msg.encode())}');
    };
  }
}
