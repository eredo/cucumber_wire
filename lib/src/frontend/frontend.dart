import 'dart:convert';
import 'dart:isolate';

import 'package:matcher/matcher.dart';

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

class Desc implements Description {
  final String text;

  Desc(this.text);

  @override
  Description add(String text) => Desc(this.text + text);

  @override
  Description addAll(
          String start, String separator, String end, Iterable list) =>
      Desc(this.text + start + list.join(separator) + end);

  @override
  Description addDescriptionOf(value) => Desc(this.text + value.toString());

  @override
  int get length => text.length;

  @override
  Description replace(String text) => Desc(text);

  @override
  String toString() => text;
}

void expect(dynamic data, dynamic eq) {
  final desc = Desc('');
  Matcher matcher;
  if (eq is Matcher) {
    matcher = eq;
  } else {
    matcher = equals(eq);
  }

  final matchState = {};
  final match = matcher.matches(data, matchState);
  if (!match) {
    final ndesc = matcher.describeMismatch(data, desc, matchState, false);
    throw ndesc.toString();
  }
}
