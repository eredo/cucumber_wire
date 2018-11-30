import 'package:test/test.dart';

import 'package:cucumber_wire/src/frontend/registry.dart';

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
