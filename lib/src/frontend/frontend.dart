import 'dart:convert';
import 'dart:isolate';

import '../server/message.dart';
import 'registry.dart';
import 'suite_loader.dart';

final _registry = StepRegistry();

void registerStepDefinitions(SendPort output, List<Type> definitions,
    {List<SuitePlugin> plugins = const []}) async {
  final input = ReceivePort();
  final loader = SuiteLoader(_registry, plugins);
  definitions.forEach(loader.load);

  output.send(input.sendPort);

  output.send(utf8.encode(json
      .encode((InternalFileMessage()..files = loader.detectFiles()).encode())));

  input.listen((m) async {
    if (m is List<int>) {
      final msg = utf8.decode(m);
      print('received in isolate: $msg');

      WireMessage message;
      try {
        message = parse(msg);
      } catch (ex) {
        print('unable to parse message: $ex');
      }

      if (message is BeginScenario) {
        output.send(utf8.encode(json.encode(ResultMessage.success().encode())));
      }

      if (message is StepMatches) {
        print('lookup step: ${message.nameToMatch}');

        final step = _registry.lookup(message.nameToMatch);
        if (step != null) {
          print('step matched');
          final msg = ResultMessage.success([
            [
              {
                'id': step.id.toString(),
                'args': step
                    .detectArgs(message.nameToMatch)
                    .map((s) => {'val': s.value, 'pos': s.position})
                    .toList()
              }
            ]
          ]);
          output.send(utf8.encode(json.encode(msg.encode())));
          return;
        }

        print('lookup not found');
        output.send(utf8.encode(json.encode(ResultMessage.fail().encode())));
      }

      if (message is Invoke) {
        WireMessage result;
        try {
          print('invoke with id: ${message.invokeId}');
          await _registry.execute(message.invokeId, message.args);
          print('success');
          result = ResultMessage.success();
        } catch (ex) {
          print('failed: $ex');
          result = ResultMessage.fail([
            {'message': ex.toString(), 'exception': ex.runtimeType.toString()}
          ]);
          print('send invoke output');
        }

        output.send(utf8.encode(json.encode(result.encode())));
      }

      if (message is EndScenario) {
        WireMessage result;

        try {
          await _registry.end();
          result = ResultMessage.success();
        } catch (ex) {
          result = ResultMessage.fail([
            {'message': ex.toString(), 'exception': ex.runtimeType.toString()}
          ]);
        }

        output.send(utf8.encode(json.encode(result.encode())));
      }
    }
  });
}
