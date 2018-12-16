class Given {
  final String matcher;
  const Given(this.matcher);
}

class Then {
  final String matcher;
  const Then(this.matcher);
}

class When {
  final String matcher;
  const When(this.matcher);
}

class And {
  final String matcher;
  const And(this.matcher);
}

class _AfterAll {
  const _AfterAll();
}

/// Determines that a method should be executed after a scenario run completed.
/// This method will only be called if one of the methods within the scenario
/// were called.
/// For worlds this will be executed if the world was used by one of the
/// scenarios.
const afterAll = _AfterAll();

class _After {
  const _After();
}

/// Determines that a method should be called whenever a method within a
/// scenario was called.
/// For worlds this method will be executed whenever a method of a scenario
/// which uses this world was executed.
const after = _After();

class _BeforeAll {
  const _BeforeAll();
}

/// Determines that a method should be executed before a scenario run starts.
/// This method will be executed when the first call of a method within the
/// scenario is called.
/// For worlds this will be executed if the world is going to be used by a
/// scenario.
const beforeAll = _BeforeAll();

class _Before {
  const _Before();
}

/// Determines that a method should be called whenever a method within a
/// scenario is called.
/// For worlds this method will be executed whenever a method of a scenario
/// which uses this world is executed.
const before = _Before();
