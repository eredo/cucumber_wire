import 'dart:mirrors';

import 'package:meta/meta.dart';

import 'registry.dart';
import 'annotations.dart';

final _thenAnnotation = reflectClass(Then);
final _givenAnnotation = reflectClass(Given);
final _whenAnnotation = reflectClass(When);
final _andAnnotation = reflectClass(And);

final _stringMatch = reflectClass(String);
final _numMatch = reflectClass(num);
final _intMatch = reflectClass(int);
final _doubleMatch = reflectClass(double);
final _boolMatch = reflectClass(bool);

/// Detects suite using mirrors. All suite classes are loaded by
class SuiteLoader {
  final Registry registry;
  final List<SuitePlugin> plugins;

  SuiteLoader(this.registry, [this.plugins]);

  void load(Type type) {
    final ClassMirror classElement = reflectType(type);
    final InstanceMirror instanceMirror =
        classElement.newInstance(Symbol(''), []);

    (<MethodMirror>[]..addAll(classElement.instanceMembers.values))
        .forEach((MethodMirror mirr) => _checkMethod(mirr, instanceMirror));
  }

  /// Detects all files loaded by the step definition setup which are in the
  /// same or in sub folders.
  List<String> detectFiles([String rootName]) {
    final libs = currentMirrorSystem().libraries.keys;
    return libs
        .where((u) => u.scheme.startsWith('file'))
        .map((uri) => uri.path)
        .toList();
  }

  void _checkMethod(MethodMirror method, InstanceMirror instanceMirror) {
    // Check if the method has one of the required annotations.
    final matcher = _getMatcherAnnotation(method.metadata);
    if (matcher != null) {
      registry.register(matcher, setup(instanceMirror, method));
    }

    if (_hasHookAfterAll(method.metadata)) {
      registry
          .registerAfterAll(() => instanceMirror.invoke(method.simpleName, []));
    }
  }

  @visibleForTesting
  FrontendCallback setup(InstanceMirror instance, MethodMirror mirr) {
    return (List<dynamic> args) {
      final passedArgs = <dynamic>[];
      for (int i = 0; i < args.length; i++) {
        if (i >= mirr.parameters.length) {
          throw ArgumentError(
              'Unable to pass arg: ${args[i]} because method only '
              'expects: ${i - 1} arguments.');
        }

        final methodArg = mirr.parameters[i];
        if (methodArg.type.isAssignableTo(_stringMatch)) {
          passedArgs.add(args[i].toString());
        } else if (methodArg.type.isAssignableTo(_numMatch)) {
          passedArgs.add(num.tryParse(args[i]));
        } else if (methodArg.type.isAssignableTo(_intMatch)) {
          passedArgs.add(int.tryParse(args[i]));
        } else if (methodArg.type.isAssignableTo(_doubleMatch)) {
          passedArgs.add(double.tryParse(args[i]));
        } else if (methodArg.type.isAssignableTo(_boolMatch)) {
          passedArgs.add(args[i].toString().toLowerCase() == 'true');
        } else {
          throw ArgumentError(
              'Unable to convert for argument: ${methodArg.simpleName.toString()} '
              'of type: ${methodArg.type.simpleName.toString()}. Please one of '
              'the supported types: String, num, int, double, bool.');
        }
      }

      for (int i = passedArgs.length; i < mirr.parameters.length; i++) {
        dynamic value;

        final param = mirr.parameters[i];
        final plugin = plugins.firstWhere(
            (p) => (value = p.apply(param, instance.reflectee)) != null,
            orElse: () => null);

        if (plugin != null) {
          passedArgs.add(value);
        } else {
          throw ArgumentError(
              'Unable to fill value for argument: ${param.simpleName.toString()}.');
        }
      }

      return instance.invoke(mirr.simpleName, passedArgs);
    };
  }
}

bool _hasHookAfterAll(List<InstanceMirror> metadata) {
  return metadata.any((i) => i.reflectee == afterAll);
}

String _getMatcherAnnotation(List<InstanceMirror> metadata) {
  final annotation = metadata.firstWhere(
      (i) => [
            _thenAnnotation,
            _givenAnnotation,
            _whenAnnotation,
            _andAnnotation,
          ].any((c) => i.type.isAssignableTo(c)),
      orElse: () => null);
  if (annotation == null) {
    return null;
  }

  return annotation.getField(#matcher).reflectee as String;
}

abstract class SuitePlugin<T, R> {
  R apply(ParameterMirror mirr, T instance);
}
