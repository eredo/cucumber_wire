import 'dart:isolate';
import 'dart:mirrors';

import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:cucumber_wire/src/frontend/suite_loader.dart';
import 'package:cucumber_wire/src/frontend/annotations.dart';
import 'package:cucumber_wire/src/frontend/registry.dart';

import 'data/test_include.dart';

void main() {
  unused();

  group('$SuiteLoader', () {
    TestRegistry registry;
    SuiteLoader loader;

    setUp(() {
      registry = TestRegistry();
      loader = SuiteLoader(registry, [FillerPlugin()]);
    });

    group('detectFiles', () {
      test('should find the files used in the directory of the file', () {
        final files = loader.detectFiles();
        expect(files, ['suite_loader_test.dart', 'data/test_include.dart']);
      }, skip: 'need a better test case for this.');
    });

    group('load', () {
      test('should register a given element', () {
        loader.load(TestSuite);
        verify(registry.register(
            'Today is ([a-zA-Z]+) the ([0-9]+) day of the week', any));
      });

      test('should register a when element', () {
        loader.load(TestSuite);
        verify(registry.register('I click on ([a-zA-Z]+)', any));
      });

      test('should register a then element', () {
        loader.load(TestSuite);
        verify(registry.register('I should see ([a-zA-Z]+)', any));
      });

      test('should register afterAll methods', () {
        loader.load(TestSuite);
        verify(registry.registerAfterAll(any));
      });

      test('should map arguments correctly', () {
        final suite = TestSuite();
        suite.cb = expectAsync2((String days, int dayIndex) {
          expect(days, 'test');
          expect(dayIndex, 12);
        });

        final inst = reflect(suite);
        final fnMirr = reflectClass(TestSuite).declarations.values.firstWhere(
            (dcl) => dcl.simpleName.toString().contains('givenFirstStuff'));
        final callback = loader.setup(inst, fnMirr);

        callback(['test', '12']);
      });

      test('should support plugins', () {
        final suite = TestSuite();
        suite.cb = expectAsync1((String days) {
          expect(days, 'filled');
        });

        final inst = reflect(suite);
        final fnMirr = reflectClass(TestSuite).declarations.values.firstWhere(
            (dcl) => dcl.simpleName.toString().contains('thenIShouldSee'));
        final callback = loader.setup(inst, fnMirr);

        callback([]);
      });
    });
  });
}

class TestSuite extends Extended {
  Function cb;

  @Given('Today is ([a-zA-Z]+) the ([0-9]+) day of the week')
  void givenFirstStuff(String day, int dayIndex) => cb(day, dayIndex);

  @When('I click on ([a-zA-Z]+)')
  void whenIam(String day) {}

  @Then('I should see ([a-zA-Z]+)')
  void thenIShouldSee(String day) => cb(day);
}

class Extended {
  @afterAll
  void methodAfterAll() {}
}

class TestRegistry extends Mock implements Registry {}

class FillerPlugin extends SuitePlugin<TestSuite, String> {
  @override
  String apply(ParameterMirror mirr, TestSuite instance) {
    return 'filled';
  }
}
