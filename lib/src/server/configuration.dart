import 'package:args/args.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

const _argPort = 'port';
const _argHostname = 'hostname';
const _argRunCucumber = 'run-cucumber';
const _argCucumberCli = 'cucumber-executable';
const _argLiveReload = 'live-reload';
const _argVerbose = 'verbose';

/// Configuration of the server, this will be either defined by the arguments
/// or when setting up a custom wire server it can be used directly.
class Configuration {
  static final _parser = ArgParser()
    ..addOption(
      _argPort,
      abbr: 'p',
      help: 'Port used to start the server.',
      defaultsTo: '56123',
    )
    ..addOption(
      _argHostname,
      abbr: 'h',
      help: 'Hostname on which the wire server listens to. This needs to '
          'equal the hostname defined within the .wire file.',
      defaultsTo: 'localhost',
    )
    ..addFlag(
      _argRunCucumber,
      abbr: 'c',
      help: 'Runs the cucumber command after step definitions are loaded or'
          'reloaded when live-reload is active.',
      defaultsTo: false,
    )
    ..addOption(
      _argCucumberCli,
      abbr: 'i',
      help: 'Path to the cucumber cli tool.',
      defaultsTo: 'cucumber',
    )
    ..addFlag(
      _argLiveReload,
      abbr: 'l',
      help: 'Listens to file changes of files included within the step '
          'definitions and reloads the step definitions in case of change.',
      defaultsTo: false,
    )
    ..addFlag(
      _argVerbose,
      abbr: 'v',
      help: 'Enables verbose logging.',
      defaultsTo: false,
    )
    ..addOption('help');

  /// Defines on which port the wire server should listen. This port needs to
  /// equal the port defined within the .wire file placed in the
  /// features/step_definitions folder.
  ///
  /// The default port is 56123.
  final int port;

  /// Hostname on which the wire server should listen.
  ///
  /// The default host is localhost.
  final String hostname;

  /// Defines whether the server should execute the cucumber executable after
  /// setting up the wire server.
  ///
  /// This is set to false by default.
  final bool runCucumber;

  /// Path to the cucumber executable which is used when [runCucumber] is set
  /// to true.
  final String cucumberExecutable;

  /// If set the server detects file changes within the step definitions and
  /// reloads them. If [runCucumber] is set to true, it will also execute
  /// cucumber after a reload.
  ///
  /// This is set to false by default.
  final bool liveReload;

  /// Path to the file which defines the test scenarios.
  final String entryPoint;

  /// Enables verbose logging within the server.
  ///
  /// Is set to false by default.
  final bool verbose;

  Configuration({
    this.port = 56123,
    this.hostname = 'localhost',
    this.runCucumber = false,
    this.liveReload = false,
    this.verbose = false,
    this.cucumberExecutable,
    @required this.entryPoint,
  }) {
    if (entryPoint?.isEmpty ?? true) {
      throw ConfigurationException();
    }
  }

  factory Configuration.fromArguments(List<String> args) {
    final argResult = _parser.parse(args);

    if (argResult.rest.isEmpty) {
      throw ConfigurationException();
    }

    String entryPoint = argResult.rest.first;
    if (path.isRelative(entryPoint)) {
      entryPoint = path.join(path.current, entryPoint);
    }

    return Configuration(
      port: int.tryParse(argResult[_argPort]) ?? 56123,
      hostname: argResult[_argHostname],
      runCucumber: argResult[_argRunCucumber],
      cucumberExecutable: argResult[_argCucumberCli],
      liveReload: argResult[_argLiveReload],
      verbose: argResult[_argVerbose],
      entryPoint: entryPoint,
    );
  }

  /// Provides the usage description of the argument parser.
  static String get usage => _parser.usage;
}

/// Thrown if the configuration is not valid during initialisation. This is
/// caught by the CLI to display the usage.
class ConfigurationException implements Exception {
  @override
  String toString() => 'configuration doesn\'t provide a step definition '
      'entry point';
}
