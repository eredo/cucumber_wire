import 'dart:mirrors';

import 'package:webdriver/sync_io.dart';
import 'package:cucumber_wire/cucumber_wire.dart';

export 'package:webdriver/sync_io.dart';

/// Example world which provides a web driver and some helper methods.
abstract class Driver {
  static WebDriver _driver;
  static bool active;

  WebDriver get driver => _driver ??=
          createDriver(uri: Uri.parse('http://localhost:9515'), desired: {
        "chromeOptions": {
          "args": ["--headless"]
        }
      });

  @And('I navigate to (.*)')
  void navigateTo(String url) {
    driver.get(url);
  }

  @afterAll
  void closeDriver() {
    _driver?.close();
    _driver = null;
  }
}

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
