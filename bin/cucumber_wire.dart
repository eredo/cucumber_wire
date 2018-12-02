import 'dart:isolate';

import 'package:cucumber_wire/server.dart';

void main(List<String> args) async {
  Server server;

  try {
    final config = Configuration.fromArguments(args);
    server = Server(config);
    server.start();
    server.bind();

    await server.complete;
    server = null;
  } on ConfigurationException catch (_) {
    print(Configuration.usage);
  } on IsolateSpawnException catch (_) {
    // This is handled by the server.
  } finally {
    await server?.close();
  }
}
