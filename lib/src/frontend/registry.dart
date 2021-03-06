import 'dart:async';

abstract class Registry {
  void register(String matcher, FrontendCallback callback);

  void registerAfterAll(HookCallback callback);

  void registerBeforeAll(HookCallback callback);
}

class StepRegistry implements Registry {
  /// Contains the registered steps where the key is the identifier, the
  /// value contains the arguments.
  final _steps = <int, Step>{};
  final _afterAll = Set<HookCallback>();
  final _beforeAll = Set<HookCallback>();

  int _id = 0;

  void register(String matcher, FrontendCallback callback) {
    final matcherExp = matcher
        .replaceAll('{string}', '["|\']([A-Za-z0-9.\\s]+)["|\']')
        .replaceAll('{int}', r'([\-\+0-9]+)')
        .replaceAll('{float}', r'([\+\-0-9\.]+)')
        .replaceAll('{word}', r'([A-Za-z0-9\_\-]+)')
        .replaceAll('{}', '(.*)');

    final step = Step(RegExp('^$matcherExp'), callback, _id++);
    _steps[step.id] = step;
  }

  Step lookup(String matcher) {
    for (final id in _steps.keys) {
      final step = _steps[id];
      if (step.matcher.hasMatch(matcher)) {
        return step;
      }
    }

    return null;
  }

  FutureOr<void> execute(String id, List<dynamic> args) async {
    final i = int.tryParse(id);
    return _steps[i].callback(args);
  }

  /// Executes all registered beforeAll functionality.
  FutureOr<void> start() => Future.wait(_beforeAll.map((fn) async {
        await fn();
      }));

  /// Executes all registered afterAll functionality.
  FutureOr<void> end() => Future.wait(_afterAll.map((fn) async {
        await fn();
      }));

  @override
  void registerAfterAll(HookCallback callback) {
    _afterAll.add(callback);
  }

  @override
  void registerBeforeAll(HookCallback callback) {
    _beforeAll.add(callback);
  }
}

class Step {
  final RegExp matcher;
  final FrontendCallback callback;
  final int id;

  Step(this.matcher, this.callback, this.id);

  List<StepArg> detectArgs(String value) {
    final matches = matcher.allMatches(value);
    int matchStart = 0;

    return matches
        .map((match) {
          final results = <StepArg>[];
          for (var matchId = 1; matchId <= match.groupCount; matchId++) {
            final matchString = match[matchId];
            final matchIndex = value.indexOf(matchString, matchStart);
            matchStart = matchIndex + 1;
            results.add(StepArg(matchString, matchIndex));
          }
          return results;
        })
        .expand((l) => l)
        .toList();
  }
}

class StepArg {
  final String value;
  final int position;

  StepArg(this.value, this.position);
}

typedef FutureOr<void> FrontendCallback(List<dynamic> args);
typedef FutureOr<void> HookCallback();
