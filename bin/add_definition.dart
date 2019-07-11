import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

final _sentenceMatcher = RegExp(r'^(\w+) (.*)$', caseSensitive: false);
final _argMatcher = RegExp(r'\{(\w+)\}');
final _argParser = ArgParser()
  ..addFlag('async',
      abbr: 'a',
      help: 'Defines that the step definition should be asynchronous')
  ..addFlag('help', abbr: 'h', help: 'Shows this usage message.');

void printUsage() {
  print('Usage: pub run cucumber_wire:add_definition [options] "<sentence>" '
      '[target_file] [target_line]\n\n'
      'Where <sentence> needs to start with either Given, And, Then or When.'
      '\n\n');
  print(_argParser.usage);
}

void main(List<String> args) async {
  ArgResults argResult;

  try {
    argResult = _argParser.parse(args);
  } catch (ex) {}

  if (argResult == null ||
      argResult['help'] ||
      (argResult.rest.isEmpty ||
          argResult.rest.length > 3 ||
          argResult.rest.length == 2)) {
    printUsage();
    exit(1);
  }

  final matches = _sentenceMatcher.allMatches(argResult.rest.first);
  if (matches.isEmpty) {
    print('Please provide a valid message as the first argument.\n'
        'Unable to parse: ${argResult.rest.first}');
    exit(2);
  }

  final kind = matches.first[1];
  final sentence = matches.first[2];
  final methodArgs = <String>[];
  final argsFound = _findArguments(sentence);

  for (var i = 0; i < argsFound.length; i++) {
    methodArgs.add('${argsFound[0]} arg$i');
  }

  final returnType = argResult['async'] ? 'FutureOr<void>' : 'void';
  final methodModifier = argResult['async'] ? 'async ' : '';
  final code = '''  @$kind('$sentence')
  $returnType ${_escapeMethod(sentence)}(${methodArgs.join(', ')}) $methodModifier{}''';

  if (argResult.rest.length == 1) {
    print(code);
  } else {
    final file = File(args[1]);
    if (!file.existsSync()) {
      print('Unable to find file: ${argResult.rest[1]}.');
      exit(3);
    }

    final lineStream = utf8.decoder
        .bind(file.openRead())
        .transform(LineSplitter());
    final targetLine = int.tryParse(argResult.rest[2]);
    if (targetLine == null) {
      print('Provide a valid line number as third argument.');
      exit(4);
    }

    int line = 0;
    final contentBuffer = StringBuffer();
    await for (final lineString in lineStream) {
      if (line == targetLine - 1) {
        contentBuffer.writeln(code);
      }
      line++;
      contentBuffer.writeln(lineString);
    }

    file.writeAsStringSync(contentBuffer.toString());
  }
}

String _escapeMethod(String sentence) => sentence
    .replaceAll(RegExp(r'\{\w+\}'), '')
    .split(' ')
    .map((s) =>
        s.split('').fold('', (v, p) => v + (v.isEmpty ? p.toUpperCase() : p)))
    .fold('', (v, p) => v + (v.isEmpty ? p.toLowerCase() : p));

List<String> _findArguments(String sentence) =>
    _argMatcher.allMatches(sentence).map((m) => m[1]).map((s) {
      switch (s) {
        case 'word':
        case 'string':
          return 'String';
        case 'int':
          return s;
        case 'float':
          return 'double';
        default:
          return 'string';
      }
    }).toList();
