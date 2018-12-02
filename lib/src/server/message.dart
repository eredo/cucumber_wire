import 'dart:convert';

import '../frontend/registry.dart';
import '../frontend/step_definition.dart';

/// Typed definition of the messages transmitted between cucumber server, the
/// cucumber_wire dart server and the dart step definition.
///
/// Message of the cucumber server are json serialized lists where the first
/// element identifies the message type followed by further arguments where the
/// elements can be of any type.
abstract class WireMessage {
  /// Declares what kind of message this is.
  String get identifier;

  /// Takes the list of elements without the identifier and parses the elements.
  void parse(List<dynamic> inputs);

  /// Transforms the [WireMessage] into a serializable list which is than encoded
  /// into a json string.
  List<dynamic> encode();
}

abstract class _InputMessage implements WireMessage {
  List<dynamic> encode() => [identifier];
}

/// Message emitted by cucumber when a scenario is started. This will cause all
/// beforeAll hooks to be executed by the [StepRegistry].
class BeginScenario extends _InputMessage implements WireMessage {
  static const String name = 'begin_scenario';
  final String identifier = name;

  @override
  void parse(List inputs) {}
}

/// First message emitted by the cucumber and before each scenario start, this
/// command tries to check whether a step is defined within the step definitions.
class StepMatches extends _InputMessage implements WireMessage {
  static const String name = 'step_matches';

  @override
  final String identifier = name;

  /// The string of the step included variables. Variables are then extracted
  /// by the [Step] done within the frontend implementation used by the
  /// step definition files.
  String nameToMatch;

  @override
  void parse(List inputs) {
    final data = inputs[0] as Map;
    nameToMatch = data['name_to_match'];
  }

  @override
  List encode() {
    return super.encode()..add({'name_to_match': nameToMatch});
  }
}

/// After a scenario is started each step is invoked using the arguments which
/// where previously detected and communicated to the cucumber server when the
/// [StepMatches] message was received.
class Invoke extends _InputMessage implements WireMessage {
  static const String name = 'invoke';

  @override
  final String identifier = name;

  String invokeId;
  List<dynamic> args;

  @override
  void parse(List inputs) {
    final data = inputs.first as Map;
    invokeId = data['id'] as String;
    args = data['args'] as List<dynamic>;
  }

  List<dynamic> encode() {
    return [
      identifier,
      {'id': invokeId, 'args': args}
    ];
  }
}

/// Message which completes a scenario and will cause all afterAll hooks to be
/// called which are registered by the [StepRegistry].
class EndScenario extends _InputMessage implements WireMessage {
  static const String name = 'end_scenario';

  @override
  final String identifier = name;

  @override
  void parse(List inputs) {}
}

/// Response message send by the step definition for each message provided by
/// the cucumber server. The result can have 3 different stats: fail, success,
/// pending. pending is yet not implemented in cucumber_wire.
///
/// Each [ResultMessage] may return further information, like error messages,
/// arguments available for a step and so on.
class ResultMessage implements WireMessage {
  final String state;
  List<dynamic> args;

  ResultMessage(this.state, [this.args = const []]);

  ResultMessage.fail([this.args = const []]) : this.state = 'fail';
  ResultMessage.success([this.args = const []]) : this.state = 'success';
  ResultMessage.pending([this.args = const []]) : this.state = 'pending';

  factory ResultMessage.failWithException(dynamic ex) => ResultMessage.fail([
        {'message': ex.toString(), 'exception': ex.runtimeType.toString()}
      ]);

  @override
  List encode() {
    final res = <dynamic>[state];
    if (args.isNotEmpty) {
      res.addAll(args);
    }
    return res;
  }

  @override
  String get identifier => null;

  @override
  void parse(List inputs) => args = inputs;
}

/// This message is only used between the isolate step definition and the server.
/// It's used to provided the server with the list of files used within the
/// step definitions.
class InternalFileMessage implements WireMessage {
  static const String name = 'internal_files';

  @override
  final String identifier = name;

  List<String> files = [];

  @override
  List encode() => [identifier]..addAll(files);

  @override
  void parse(List inputs) {
    files = inputs.cast<String>();
  }
}

class InternalDefinitionList implements WireMessage {
  static const String name = 'internal_definition_list';

  List<StepDefinition> declarations = [];

  @override
  List encode() => [name]..addAll(declarations.map((d) => d.toJson()));

  @override
  String get identifier => name;

  @override
  void parse(List inputs) {
    declarations = inputs
        .map((o) => StepDefinition.fromJson(o as Map<String, dynamic>))
        .toList();
  }
}

/// Decodes the json [input] and tries to convert it into a [WireMessage] implementation.
///
/// Throws [MessageParseException] if the message doesn't contain any elements
/// or the message identifier was unknown.
WireMessage parse(String input) {
  final data = json.decode(input) as List<dynamic>;
  if (data.isEmpty) {
    throw MessageParseException('missing first identifier', input);
  }

  WireMessage msg;
  switch (data[0]) {
    case BeginScenario.name:
      msg = BeginScenario();
      break;
    case EndScenario.name:
      msg = EndScenario();
      break;
    case StepMatches.name:
      msg = StepMatches();
      break;
    case Invoke.name:
      msg = Invoke();
      break;
    case InternalFileMessage.name:
      msg = InternalFileMessage();
      break;
    case InternalDefinitionList.name:
      msg = InternalDefinitionList();
      break;
    case 'success':
    case 'fail':
    case 'pending':
      msg = ResultMessage(data[0], data.skip(1).toList());
      break;
    default:
      throw MessageParseException('unknown identifier: ${data[0]}', input);
  }

  msg.parse(data.skip(1).toList().cast<dynamic>());
  return msg;
}

/// Thrown by [parse] if the message didn't match the expectations.
class MessageParseException implements Exception {
  final String message;
  final String input;

  MessageParseException(this.message, this.input);
}
