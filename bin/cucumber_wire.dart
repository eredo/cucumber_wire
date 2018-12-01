import 'package:cucumber_wire/server.dart';

void main(List<String> args) async {
  try {
    final config = Configuration.fromArguments(args);
    final server = Server(config);
    server.start();
    server.bind();

    await server.complete;
  } on ConfigurationException catch (_) {
    print(Configuration.usage);
  }
}
