import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'message.dart';
import 'isolate_handler.dart';

/// Server implementation which opens a TCP socket, transforms the messages
/// received through the socket into a [WireMessage] representation and emits these
/// in [onMessage]. Within the server setup, these messages are than forwarded
/// to the step definition file using the [IsolateHandler].
class WireServer implements Sink<WireMessage> {
  final _messages = StreamController<WireMessage>.broadcast();
  final _input = StreamController<WireMessage>.broadcast();
  final _sockets = <Socket>[];

  final String address;
  final int port;

  ServerSocket _serverSocket;

  Stream<WireMessage> get onMessage => _messages.stream;

  WireServer({this.address = '0.0.0.0', this.port = 9090});

  Future<WireServer> start() {
    return ServerSocket.bind(address, port).then((serverSocket) {
      _serverSocket = serverSocket;

      serverSocket.listen(
        (socket) {
          // Handles the input stream which is used to send message through the
          // socket. This is closed when the socket disconnects.
          StreamSubscription<List<int>> inputListener;

          _sockets.add(socket);
          socket
              .transform(utf8.decoder)
              .where((s) => s.isNotEmpty && s[0] == '[')
              .map(parse)
              .listen((msg) {
            _messages.add(msg);
          }, onDone: () {
            _sockets.remove(socket);
            inputListener.cancel();
            inputListener = null;
          });

          inputListener = _input.stream
              .map((m) => m.encode())
              .map(json.encode)
              .map((r) => '$r\n')
              .transform(utf8.encoder)
              .listen((d) async {
            socket.add(d);
            await socket.flush();
          });
        },
        cancelOnError: false,
      );
    });
  }

  Future<void> close() {
    final sockets = []..addAll(_sockets);
    sockets.forEach((s) => s.destroy());
    return _serverSocket.close();
  }

  @override
  void add(WireMessage data) => _input.add(data);
}
