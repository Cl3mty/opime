import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opime/core/assistant/assistant_models.dart';
import 'package:opime/core/assistant/google_ai_client.dart';

void main() {
  group('listModels', () {
    test(
      'ne garde que les modèles supportant generateContent, préfixe '
      '"models/" retiré, triés',
      () async {
        final client = GoogleAiClient(
          httpClient: MockClient((request) async {
            expect(request.url.queryParameters['key'], 'goog-test');
            return http.Response(
              jsonEncode({
                'models': [
                  {
                    'name': 'models/gemini-1.5-pro',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                  {
                    'name': 'models/embedding-001',
                    'supportedGenerationMethods': ['embedContent'],
                  },
                  {
                    'name': 'models/gemini-1.5-flash',
                    'supportedGenerationMethods': ['generateContent'],
                  },
                ],
              }),
              200,
            );
          }),
        );

        final models = await client.listModels('goog-test');

        expect(models, ['gemini-1.5-flash', 'gemini-1.5-pro']);
      },
    );

    test('clé invalide (403) : message dédié', () async {
      final client = GoogleAiClient(
        httpClient: MockClient((request) async => http.Response('', 403)),
      );

      await expectLater(
        client.listModels('goog-bad'),
        throwsA(
          isA<GoogleAiException>().having(
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
      'mappe le rôle assistant sur "model" et extrait le message système '
      'dans systemInstruction',
      () async {
        late Map<String, dynamic> sentBody;
        final client = GoogleAiClient(
          httpClient: MockClient.streaming((request, bodyStream) async {
            sentBody = jsonDecode(
              await bodyStream.transform(utf8.decoder).join(),
            );
            return http.StreamedResponse(const Stream.empty(), 200);
          }),
        );

        await client.streamChat(
          apiKey: 'goog-test',
          model: 'gemini-1.5-pro',
          messages: const [
            AssistantMessage(
              role: AssistantRole.system,
              content: 'Tu es un assistant financier.',
            ),
            AssistantMessage(role: AssistantRole.user, content: 'Salut'),
            AssistantMessage(
              role: AssistantRole.assistant,
              content: 'Bonjour !',
            ),
          ],
        );

        expect(
          sentBody['systemInstruction']['parts'][0]['text'],
          'Tu es un assistant financier.',
        );
        expect(sentBody['contents'], [
          {
            'role': 'user',
            'parts': [
              {'text': 'Salut'},
            ],
          },
          {
            'role': 'model',
            'parts': [
              {'text': 'Bonjour !'},
            ],
          },
        ]);
      },
    );

    test('accumule le texte des candidats successifs (alt=sse)', () async {
      final events = [
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Bon'},
                ],
              },
            },
          ],
        })}\n',
        'data: ${jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'jour'},
                ],
              },
            },
          ],
        })}\n',
      ];
      final client = GoogleAiClient(
        httpClient: MockClient.streaming(
          (request, bodyStream) async => http.StreamedResponse(
            Stream.fromIterable(events.map(utf8.encode)),
            200,
          ),
        ),
      );

      final received = <String>[];
      final answer = await client.streamChat(
        apiKey: 'goog-test',
        model: 'gemini-1.5-pro',
        messages: const [
          AssistantMessage(role: AssistantRole.user, content: 'Salut'),
        ],
        onToken: received.add,
      );

      expect(answer, 'Bonjour');
      expect(received, ['Bon', 'jour']);
    });
  });
}
