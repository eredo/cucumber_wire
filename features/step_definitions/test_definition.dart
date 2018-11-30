import 'dart:isolate';

import 'package:cucumber_wire/cucumber_wire.dart';
import 'package:webdriver/sync_io.dart';

import 'driver.dart';

void main(List<String> args, SendPort sendPort) {
  // Sets up the step_definitions.
  registerStepDefinitions(sendPort, [
    TestScenario,
    SecondScenario,
  ], plugins: [
    ByCssSelectorPlugin(),
  ]);
}

/// An actual scenario
class TestScenario extends Driver {
  @Given("we're all wired")
  void allWired() {}

  @Then(r'I see the download button containing the text "([A-Za-z\s+]+)"')
  void openTheBrowser(
      String text, @By.cssSelector('input[type="submit"]') WebElement button) {
    expect(button.attributes['value'], contains(text));
  }

  @Then('I want to do something')
  void wantToDoSomething() {
    // ...
  }
}

class SecondScenario extends Driver {
  @Given("there's light")
  void thereIsLight() {}
}
