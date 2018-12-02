import 'dart:convert';
import 'dart:io';

import 'package:cucumber_wire/src/frontend/step_definition.dart';
import 'package:path/path.dart' as path;

import 'package:cucumber_wire/server.dart';
import 'package:cucumber_wire/src/server/isolate_handler.dart';
import 'package:cucumber_wire/src/server/message.dart';

void main(List<String> args) async {
  final config = Configuration.fromArguments(args);
  final isolate = IsolateHandler(Uri.parse(config.entryPoint));
  await isolate.onStart.first;

  isolate.add(InternalDefinitionList());
  final definitions = await isolate.onMessage
      .where((m) => m is InternalDefinitionList)
      .cast<InternalDefinitionList>()
      .first;

  print(json.encode(definitions.declarations
      .map((d) => StepDefinition(
            d.declaration,
            null,
            null,
            path.relative(d.location.replaceFirst('file://', ''),
                from: Directory.current.path),
          ))
      .toList()));
  exit(0);
}
