# cucumber_wire

An implementation of cucumber using the cucumber wire protocol.

## Usage

There are several ways to use this package. For a regular use setup a dart project and add this package as a dependency:

```yaml
name: my_cucumber_features

dependency:
  cucumber_wire: any
```

Then setup your features folder containing a `.feature` file and a `step_definitions` folder, in which you add a 
`dart_server.wire` file including the following content:

```yaml
host: localhost
port: 9090
```

Add a step definition dart file which registers the scenarios (ex: `features/step_definitions/definitions.dart`).
The `cucumber_wire` package exports the `package:matcher/matcher.dart` so matcher are directly available as well as a
simple `expect` function.

```dart
// You may import further tests
import 'package:cucumber_wire/cucumber_wire.dart';

void main(_, SendPort port) {
  // The port is provided by the runner when this step definition dart file is loaded and is used to communicate 
  // between this dart file and the server.
  registerStepDefinitions(sendPort, [
    TestScenario,
  ]);
}

class TestScenario {
  @Given("we're all wired")
  void allWired() {}

  @Then(r'I see the download button with text "([A-Za-z\s+]+)"')
  void openTheBrowser(String text) {
    expect(button.text, text);
  }

  @Then('I want to do something')
  void wantToDoSomething() {
    // ...
  }
}
```

Start the `cucumber_wire` server using `pub run` pointing to your entry point file.

```
pub run cucumber_wire features/step_definitions/definitions.dart
```

Afterwards start your cucumber runner:

```
cucumber -f pretty
```

## Setting up scenarios

Scenario classes contain methods which define steps. These steps are annotated with `@Then`, `@And`, `@Given` and `@When`.
The name of the method is not relevant. Within the step annotations a regular expression string is defined, which will
be extended by the scenario loader when the scenario is added to `registerStepDefinitions`, meaning the original
expression string: `It's a ([a-z]+)` will be turned into `^It's a ([a-z]+)`, to make it a valid expression and save some
overhead. 

The matches of the regular expression are than passed to the method as parameters when the step is executed, meaning 
there need to be at least the same number of parameters for a method than potential matches within the pattern. If the 
parameter type is not of type string, the runner will try to convert the passed value from cucumber into the proper dart 
type, which is currently only supported for `bool` (string == "true"), `int`, `double` and `num`.

The scenario needs to have at least one default named constructor (or no constructor at all) in order for the runner to 
initiate an instance of the scenario. 

```dart
void main(_, SendPort port) {
  // The port is provided by the runner when this step definition dart file is loaded and is used to communicate 
  // between this dart file and the server.
  registerStepDefinitions(sendPort, [
    TestScenario,
  ]);
}

class TestScenario {
  @Given("we're all wired")
  void allWired() {}

  @Then(r'I see the download button with text "([A-Za-z\s+]+)"')
  void openTheBrowser(String text) {
    expect(button.text, text);
  }

  @Then('I want to do something')
  void wantToDoSomething() {
    // ...
  }
}
```

## Current implementation of worlds

Currently worlds should be defined as `abstract class` and shared across scenarios using inheritance. If variables of
a world should be initiated only once use getters which refer to a static property of the world.

```dart
// Example scenario with multiple worlds.
class MyScenario1 extends DriverWorld with MagicWorld {
  @When('I open the browser at (.*)')
  void openTheBrowser(String url) => driver.get(url);
  
  @And('I activate magic')
  void activateMagic() => isActive = true;
  
  @Then('all is good')
  void allIsGood() => expect(allGood, isTrue);
}
class MyScenario2 extends DriverWorld {}

// A world 
abstract class DriverWorld {
  // Static property so each instance of DriverWorld shares the driver.
  static WebDriver _driver;
  // This getter checks whether _driver is not null, if it is null the initiation expression is executed.
  WebDriver get driver => _driver ??= createDriver();
  
  @afterAll
  void closeDriver() {
    _driver?.close();
    _driver = null;
  }
}

abstract class MagicWorld {
  // Example of getter and setter usage.
  static bool _isActive = false;
  
  bool get isActive => _isActive;
  
  set isActive(bool active) {
    assert(_isActive != active, 'Active cannot be set to the same value twice, something went wrong.');
    _isActive = active;
  }
  
  // Static variable can also be used instantly
  static bool allGood = true;
}
```

### Proposal for worlds

> **Note: This is a proposal and not yet implemented.**

Worlds should be provided by dependency injection.

```dart
void main(_, port) {
  registerStepDefinitions(port, [
    TestScenario,
  ], providers: [
    TestWorld,
  ]);
}

class TestScenario {
  final TestWorld world;
  TestScenario(this.world);
}

class TestWorld {}
```

## Passing environment variables

Environment variables can be passed to the server when starting it like this:

```
USERNAME=mysecret pub run cucumber_wire
```

Then they can be accessed within the dart step definitions using the `.fromEnvironment` methods provided for several 
build in types in dart, for example a [String](https://api.dartlang.org/stable/2.1.0/dart-core/String/String.fromEnvironment.html):

```dart
final username = String.fromEnvironment('USERNAME');
```

## Plugins

Plugins help to provide further details to a step definition method and do steps before executing the method. Plugins
are imported within the step definition and as such can be defined outside of this package. A possible first implementation
of a plugin could be `cucumber_wire_webdriver` which is currently available in `features/step_definitions/driver.dart`.

A plugin contains a method `apply` which is called for each step parameter which is not defined by the expression before
the method is called.

```dart
@When('I open the browser at (.*)')
void openTheBrowserAt(String url, String thisParameterIsForPlugin) {}
```

The first plugin in the list of registered plugins within `registerStepDefinitions` which returns an other value than
`null` in it's `apply` method is used. The `apply` method receives a [ParameterMirror](https://api.dartlang.org/stable/2.1.0/dart-mirrors/ParameterMirror-class.html)
which is used to gather the information of the parameter and as a second argument the instance of the scennario class which 
contains the method. Therefore the instance of the scenario can be used to gather further information or execute
additional steps (which at this point may only be synchronous).

An example for a plugin can be seen below, which enables an annotation for parameters to use the `WebDriver` to fetch
a `WebElement` using a CSS selector, where the instance of the scenario needs to inherit the `Driver` world.

```dart
/// Example plugin to support build in annotations for CssSelectors.
class ByCssSelectorPlugin extends SuitePlugin<Driver, WebElement> {
  final _by = reflectClass(By);

  @override
  WebElement apply(ParameterMirror mirr, Driver instance) {
    final selector = _selector(mirr);
    if (selector != null) {
      return instance.driver.findElement(selector);
    }

    return null;
  }

  By _selector(ParameterMirror mirr) {
    for (final meta in mirr.metadata) {
      if (meta.type.isAssignableTo(_by)) {
        return meta.reflectee;
      }
    }

    return null;
  }
}
```

After registering the plugin to the `registerStepDefinitions` function, it's available to all scenarios registered within
the same function as well.

```dart
void main(_, SendPort sendPort) {
  registerStepDefinitions(sendPort, [
    TestScenario
  ], plugins: [
    ByCssSelectorPlugin(),
  ]);
}

class TestScenario extends Driver {
  @Then(r'I see the download button with text "([A-Za-z\s+]+)"')
  void openTheBrowser(
      String text, @By.cssSelector('.install-download') WebElement button) {
    expect(button.text, text);
  }
}
```

## How it works


## Known issues

- `@afterAll`, `@beforeAll` methods on worlds might be executed multiple times, therefore add a bool check whether the
  method was already executed otherwise skip function. Null operators help in this case `_driver ??= createDriver()`.
  `_driver?.close(); _driver = null;`.

## Roadmap

- Support configuration with configuration file parameters which are then either passed as environment variables or
  available for access by injection.
- Integration with `package:test`.
- Support for multiple entry point files.
- Examples for Intellij live code templates for ease of use.
- Support asynchronous plugins
- Dependency injection of scenarios and worlds.
- Debugging story including running `pub run cucumber` and providing a debug port.
- Applying new mixin patterns to worlds and plugins.
- Add analyzer plugin to validate scenarios, potential analyzer warnings/lints:
  - Number of parameters doesn't match the amount of pattern matches. 
  - Step definition already exists in a different scenario.
- Provide optional arguments and named arguments (`@Then('Button label :label should :equal')`)