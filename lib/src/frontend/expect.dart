import 'package:matcher/matcher.dart' hide Description;

import 'description.dart';

/// Assert that [actual] matches [matcher].
///
/// [matcher] can be a value in which case it will be wrapped in an
/// [equals] matcher.
/// TODO: Use the expect provided by test.
void expect(dynamic actual, dynamic matcher) {
  final desc = Description('');
  Matcher matchFn;
  if (matcher is Matcher) {
    matchFn = matcher;
  } else {
    matchFn = equals(matcher);
  }

  final matchState = {};
  final match = matchFn.matches(actual, matchState);
  if (!match) {
    final ndesc = matchFn.describeMismatch(actual, desc, matchState, false);
    throw ndesc.toString();
  }
}
