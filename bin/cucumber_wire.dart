import 'dart:io';
import 'dart:convert';

import 'package:args/args.dart';

import 'package:cucumber_wire/src/server/server.dart';
import 'package:cucumber_wire/src/server/message.dart';
import 'package:cucumber_wire/src/server/isolate_handler.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port',
        abbr: 'p', help: 'Port used to start the server.', defaultsTo: '9090')
    ..addFlag('cucumber',
        abbr: 'c',
        help: 'Runs the cucumber command on change.',
        defaultsTo: false)
    ..addOption('help');
  final argResult = parser.parse(args);

  final server = WireServer();
  await server.start();
  print('server running: ${server.address}:${server.port}');

  final isolateHandler =
      IsolateHandler(Uri.parse('../' + argResult.rest.first));

  ProcessSignal.sigterm.watch().listen((_) async {
    await server.close();
    exit(0);
  });

  isolateHandler.onMessage.listen(server.add);

  server.onMessage
      .map((e) => e.encode())
      .map(json.encode)
      .map((s) => 'received: $s')
      .listen(print);

  server.onMessage.where((msg) => msg is StepMatches).listen((m) {
    print('send step matches response');
    isolateHandler.add(m);
  });

  server.onMessage.where((msg) => msg is BeginScenario).listen((m) {
    print('send BeginScenario response');
    server.add(ResultMessage.success());
  });

  server.onMessage
      .where((msg) => msg is Invoke)
      .cast<Invoke>()
      .listen((Invoke m) {
    print('send Invoke response: ${m.args}');
    isolateHandler.add(m);
  });

  server.onMessage.where((msg) => msg is EndScenario).listen((m) {
    print('send EndScenario response');
    isolateHandler.add(m);
  });

  if (argResult['cucumber']) {
    print('setup listener for cucumber');
    isolateHandler.onStart.listen((_) async {
      final result = await Process.run(
          '/Users/eric/.gem/ruby/2.3.0/bin/cucumber', ['-f', 'pretty']);
      print(result.stdout);
    });
  }
}
