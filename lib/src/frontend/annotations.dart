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

const afterAll = _AfterAll();

class _BeforeAll {
  const _BeforeAll();
}

const beforeAll = _BeforeAll();
