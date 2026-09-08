import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opime/core/assistant/assistant_models.dart';
import 'package:opime/core/assistant/openai_client.dart';

void main() {
  group('listModels', () {
    test('filtre les modèles non conversationnels et trie le reste', () async {
      final client = OpenAiClient(
        httpClient: MockClient((request) async {
          expect(request.url.toString(), 'https://api.openai.com/v1/models');
          expect(request.headers['Authorization'], 'Bearer sk-test');
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'gpt-4o'},
                {'id': 'text-embedding-3-small'},
                {'id': 'whisper-1'},
                {'id': 'gpt-3.5-turbo'},
              ],
            }),
            200,
          );
        }),
      );

      final models = await client.listModels('sk-test');

      expect(models, ['gpt-3.5-turbo', 'gpt-4o']);
    });

    test('clé invalide (401) : message dédié', () async {
      final client = OpenAiClient(
        httpClient: MockClient((request) async => http.Response('', 401)),
      );

      await expectLater(
        client.listModels('sk-bad'),
        throwsA(
          isA<OpenAiException>().having(
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
      'accumule le contenu streamé (SSE), y compris une ligne coupée entre '
      'deux paquets, et s\'arrête sur [DONE]',
      () async {
        final chunks = [
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'Bon'},
              },
            ],
          })}\n',
          'data: ${jsonEncode({
            'choices': [
              {
                'delta': {'content': 'jour'},
              },
            ],
          })}\n'
              'data: [DONE]\n',
        ];
        final client = OpenAiClient(
          httpClient: MockClient.streaming((request, bodyStream) async {
            expect(
              request.url.toString(),
              'https://api.openai.com/v1/chat/completions',
            );
            return http.StreamedResponse(
              Stream.fromIterable(chunks.map(utf8.encode)),
              200,
            );
          }),
        );

        final received = <String>[];
        final answer = await client.streamChat(
          apiKey: 'sk-test',
          model: 'gpt-4o',
          messages: const [
            AssistantMessage(role: AssistantRole.user, content: 'Salut'),
          ],
          onToken: received.add,
        );

        expect(answer, 'Bonjour');
        expect(received, ['Bon', 'jour']);
      },
    );

    test(
      'erreur HTTP non-200 sans corps JSON exploitable : message générique',
      () async {
        final client = OpenAiClient(
          httpClient: MockClient.streaming(
            (request, bodyStream) async => http.StreamedResponse(
              Stream.value(utf8.encode('quota exceeded')),
              429,
            ),
          ),
        );

        await expectLater(
          client.streamChat(
            apiKey: 'sk-test',
            model: 'gpt-4o',
            messages: const [
              AssistantMessage(role: AssistantRole.user, content: 'Salut'),
            ],
          ),
          throwsA(
            isA<OpenAiException>().having(
              (e) => e.message,
              'message',
              contains('Quota'),
            ),
          ),
        );
      },
    );

    test(
      '429 avec quota épuisé (insufficient_quota) : le vrai message '
      'd\'OpenAI est affiché, pas un générique "réessaie plus tard" '
      'trompeur — un compte sans crédit renvoie 429 dès le tout premier '
      'appel, retenter ne change rien',
      () async {
        final client = OpenAiClient(
          httpClient: MockClient.streaming(
            (request, bodyStream) async => http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'error': {
                      'message':
                          'You exceeded your current quota, please check '
                          'your plan and billing details.',
                      'type': 'insufficient_quota',
                      'code': 'insufficient_quota',
                    },
                  }),
                ),
              ),
              429,
            ),
          ),
        );

        await expectLater(
          client.streamChat(
            apiKey: 'sk-test',
            model: 'gpt-4o',
            messages: const [
              AssistantMessage(role: AssistantRole.user, content: 'Salut'),
            ],
          ),
          throwsA(
            isA<OpenAiException>().having(
              (e) => e.message,
              'message',
              contains('You exceeded your current quota'),
            ),
          ),
        );
      },
    );
  });
}
