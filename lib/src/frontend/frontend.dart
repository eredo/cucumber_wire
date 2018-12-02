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

  input
      .where((m) => m is List<int>)
      .cast<List<int>>()
      .transform(utf8.decoder)
      .map(parse)
      .asyncMap((message) async {
        if (message is BeginScenario) {
          await _registry.start();
          return ResultMessage.success();
        }

        if (message is StepMatches) {
          final step = _registry.lookup(message.nameToMatch);
          if (step != null) {
            return ResultMessage.success([
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
          }
        }

        if (message is Invoke) {
          await _registry.execute(message.invokeId, message.args);
          return ResultMessage.success();
        }

        if (message is EndScenario) {
          await _registry.end();
          return ResultMessage.success();
        }

        if (message is InternalDefinitionList) {
          return InternalDefinitionList()
            ..declarations = loader.definitions.toList();
        }

        return ResultMessage.failWithException(
            Exception('Unknown message send'));
      })
      .map((r) => json.encode(r.encode()))
      .transform(utf8.encoder)
      .listen(
        output.send,
        onError: (err, stackTrace) {
          print('Error in isolate: $err\n$stackTrace');
          output.send(utf8.encode(
              json.encode(ResultMessage.failWithException(err).encode())));
        },
        cancelOnError: false,
      );
}
