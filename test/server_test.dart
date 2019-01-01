import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:cucumber_wire/src/server/wire_server.dart';
import 'package:cucumber_wire/src/server/message.dart';

void main() {
  group('CucumberServer', () {
    WireServer server;
    Socket client;

    void send(List<dynamic> data) {
      final msg = json.encode(data);
      client.add(utf8.encode(msg));
    }

    setUpAll(() async {
      server = WireServer();
      await server.start();

      client = await Socket.connect(server.address, server.port);
    });

    tearDownAll(() async {
      await client.close();
      await server.close();
    });

    test('should receive a simple message', () {
      server.onMessage.listen(expectAsync1((WireMessage msg) {
        expect(msg, TypeMatcher<StepMatches>());
        expect((msg as StepMatches).nameToMatch, 'we\'re all wired');
      }));

      send([
        'step_matches',
        {'name_to_match': 'we\'re all wired'}
      ]);
    });

    test('should send messages', () {
      client
          .transform(utf8.decoder)
          .map(json.decode)
          .listen(expectAsync1((obj) {
        expect(obj, TypeMatcher<List>());
        expect((obj as List).first, 'success');
      }));

      server.add(ResultMessage.success());
    }, timeout: Timeout(Duration(seconds: 5)));
  });
}
