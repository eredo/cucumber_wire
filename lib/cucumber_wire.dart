/// Library for writing cucumber step definitions for the cucumber_wire server
/// to read. To setup step definitions create a main entry point which calls the
/// [registerStepDefinitions] function and provides the scenarios.
///
/// __Example usage__
///
///     void main(_, SendPort port) {
///       registerStepDefinitions(port, [
///         TestScenario,
///       ], plugins: [SomePlugin()]);
///     }
///
library cucumber_wire;

import 'src/frontend/frontend.dart';

export 'src/frontend/frontend.dart' show registerStepDefinitions, expect;
export 'src/frontend/annotations.dart';
export 'src/frontend/suite_loader.dart' show SuitePlugin;
export 'package:matcher/matcher.dart';
