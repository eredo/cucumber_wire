import 'package:cucumber_wire/src/frontend/registry.dart';
import 'package:test/test.dart';

void main() {
  final fn = (List<dynamic> args) {
    expect(args[0], 'something');
  };

  group('$StepRegistry', () {
    StepRegistry registry;

    setUp(() {
      registry = StepRegistry();
    });

    test('should use regular expressions to find steps', () {
      final match = 'I should see ([a-zA-Z]+)';

      registry.register(match, fn);
      final step = registry.lookup('I should see something');

      expect(step, isNotNull);
    });

    test('should support {string} lookup', () {
      registry.register('I want to see {string} value', fn);
      expect(registry.lookup('I want to see "test" value'), isNotNull);
      expect(registry.lookup('I want to see test value'), isNull);
      expect(registry.lookup('I want to see \'test\' value'), isNotNull);
      expect(registry.lookup('I want to see \'test str\' value'), isNotNull);
      expect(
          registry.lookup('I want to see \'test str 192\' value'), isNotNull);
    });

    test('should support {int} lookup', () {
      registry.register('I want to see {int} value', fn);
      expect(registry.lookup('I want to see 1 value'), isNotNull);
      expect(registry.lookup('I want to see -1 value'), isNotNull);
      expect(registry.lookup('I want to see +1 value'), isNotNull);
      expect(registry.lookup('I want to see 123 value'), isNotNull);
      expect(registry.lookup('I want to see t1 value'), isNull);
      expect(registry.lookup('I want to see 1.1 value'), isNull);
      expect(registry.lookup('I want to see A value'), isNull);
    });

    test('should support {float} lookup', () {
      registry.register('I want to see {float} value', fn);
      expect(registry.lookup('I want to see 1.1 value'), isNotNull);
      expect(registry.lookup('I want to see 0.1 value'), isNotNull);
      expect(registry.lookup('I want to see -0.1 value'), isNotNull);
      expect(registry.lookup('I want to see +0.1 value'), isNotNull);
      expect(registry.lookup('I want to see 1 value'), isNotNull);
      expect(registry.lookup('I want to see A value'), isNull);
      expect(registry.lookup('I want to see A1 value'), isNull);
    });

    test('should support {word} lookup', () {
      registry.register('I want to see {word} value', fn);
      expect(registry.lookup('I want to see test value'), isNotNull);
      expect(registry.lookup('I want to see 1 value'), isNotNull);
      expect(registry.lookup('I want to see a1 value'), isNotNull);
      expect(registry.lookup('I want to see B1 value'), isNotNull);
      expect(registry.lookup('I want to see B value'), isNotNull);
      expect(registry.lookup('I want to see A t value'), isNull);
      expect(registry.lookup('I want to see test 1 value'), isNull);
    });

    test('should support {} lookup', () {
      registry.register('I want to see {} value', fn);
      expect(registry.lookup('I want to see test value'), isNotNull);
      expect(registry.lookup('I want to see 1 value'), isNotNull);
      expect(registry.lookup('I want to see a1 value'), isNotNull);
      expect(registry.lookup('I want to see B1 value'), isNotNull);
      expect(registry.lookup('I want to see B value'), isNotNull);
      expect(registry.lookup('I want to see test blub value'), isNotNull);
      expect(registry.lookup('I want to see "test ?blub value'), isNotNull);
    });
  });

  group('$Step', () {
    test('should provide the arguments based on the input', () {
      final step = Step(
          RegExp('^I should see ([a-zA-Z]+) between ([0-9]+) and ([0-9]+)'),
          fn,
          0);
      final args = step.detectArgs('I should see something between 5 and 10');

      expect(args, hasLength(3));
      expect(args[0].value, 'something');
      expect(args[0].position, 13);
      expect(args[1].value, '5');
      expect(args[1].position, 31);
      expect(args[2].value, '10');
      expect(args[2].position, 37);
    });
  });
}
