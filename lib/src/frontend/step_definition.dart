class StepDefinition {
  final String declaration;
  final String scenario;
  final String methodName;
  final String location;

  StepDefinition(
      this.declaration, this.scenario, this.methodName, this.location);

  StepDefinition.fromJson(Map<String, dynamic> map)
      : this(map['declaration'], map['scenarion'], map['method'],
            map['location']);

  Map<String, dynamic> toJson() => {
        'declaration': declaration,
        'location': location.replaceAll(r'\n', r''),
      };

  @override
  bool operator ==(other) {
    if (other is StepDefinition) {
      return declaration == other.declaration &&
          scenario == other.scenario &&
          methodName == other.methodName &&
          location == other.location;
    }

    return false;
  }
}
