import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opime/core/assistant/anthropic_client.dart';
import 'package:opime/core/assistant/assistant_models.dart';

void main() {
  group('listModels', () {
    test('trie les modèles retournés par ordre alphabétique', () async {
      final client = AnthropicClient(
        httpClient: MockClient((request) async {
          expect(request.headers['x-api-key'], 'sk-ant-test');
          expect(request.headers['anthropic-version'], isNotNull);
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'claude-opus-4'},
                {'id': 'claude-haiku-4'},
              ],
            }),
            200,
          );
        }),
      );

      final models = await client.listModels('sk-ant-test');

      expect(models, ['claude-haiku-4', 'claude-opus-4']);
    });

    test('clé invalide (401) : message dédié', () async {
      final client = AnthropicClient(
        httpClient: MockClient((request) async => http.Response('', 401)),
      );

      await expectLater(
        client.listModels('sk-bad'),
        throwsA(
          isA<AnthropicException>().having(
            (e) => e.message,
            'message',
            contains('invalide'),
          ),
        ),
      );
    });
  });

  group('streamChat', () {
    test(
      'extrait le message système dans le champ `system`, ne l\'envoie pas '
      'dans `messages`',
      () async {
        late Map<String, dynamic> sentBody;
        final client = AnthropicClient(
          httpClient: MockClient.streaming((request, bodyStream) async {
            sentBody = jsonDecode(await bodyStream.transform(utf8.decoder).join());
            return http.StreamedResponse(const Stream.empty(), 200);
          }),
        );

        await client.streamChat(
          apiKey: 'sk-ant-test',
          model: 'claude-opus-4',
          messages: const [
            AssistantMessage(
              role: AssistantRole.system,
              content: 'Tu es un assistant financier.',
            ),
            AssistantMessage(role: AssistantRole.user, content: 'Salut'),
          ],
        );

        expect(sentBody['system'], 'Tu es un assistant financier.');
        expect(sentBody['messages'], [
          {'role': 'user', 'content': 'Salut'},
        ]);
      },
    );

    test('accumule le texte des évènements content_block_delta', () async {
      final events = [
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': 'Bon'},
        })}\n',
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'delta': {'type': 'text_delta', 'text': 'jour'},
        })}\n'
            'data: ${jsonEncode({'type': 'message_stop'})}\n',
      ];
      final client = AnthropicClient(
        httpClient: MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.fromIterable(events.map(utf8.encode)),
            200,
          ),
        ),
      );

      final received = <String>[];
      final answer = await client.streamChat(
        apiKey: 'sk-ant-test',
        model: 'claude-opus-4',
        messages: const [
          AssistantMessage(role: AssistantRole.user, content: 'Salut'),
        ],
        onToken: received.add,
      );

      expect(answer, 'Bonjour');
      expect(received, ['Bon', 'jour']);
    });

    test('un évènement de type `error` lève AnthropicException', () async {
      final event =
          'data: ${jsonEncode({
            'type': 'error',
            'error': {'message': 'Clé API invalide.'},
          })}\n';
      final client = AnthropicClient(
        httpClient: MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.value(utf8.encode(event)),
            200,
          ),
        ),
      );

      await expectLater(
        client.streamChat(
          apiKey: 'sk-ant-test',
          model: 'claude-opus-4',
          messages: const [
            AssistantMessage(role: AssistantRole.user, content: 'Salut'),
          ],
        ),
        throwsA(
          isA<AnthropicException>().having(
            (e) => e.message,
            'message',
            'Clé API invalide.',
          ),
        ),
      );
    });
  });
}
