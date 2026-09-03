import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opime/core/assistant/llm_error_message.dart';

void main() {
  group('llmApiErrorMessage', () {
    test('corps JSON avec error.message : le message réel est repris', () {
      final body = jsonEncode({
        'error': {'message': 'You exceeded your current quota.'},
      });

      final message = llmApiErrorMessage(
        providerName: 'OpenAI',
        statusCode: 429,
        body: body,
      );

      expect(message, 'OpenAI : You exceeded your current quota.');
    });

    test('401 sans corps JSON exploitable : message clé invalide générique', () {
      final message = llmApiErrorMessage(
        providerName: 'OpenAI',
        statusCode: 401,
        body: '',
      );

      expect(message, contains('invalide'));
    });

    test('429 sans corps JSON exploitable : message quota générique', () {
      final message = llmApiErrorMessage(
        providerName: 'Anthropic',
        statusCode: 429,
        body: 'quota exceeded',
      );

      expect(message, contains('Quota Anthropic'));
    });

    test(
      'invalidKeyStatusCodes personnalisé (Google AI : 400/403 plutôt que '
      '401)',
      () {
        expect(
          llmApiErrorMessage(
            providerName: 'Google AI',
            statusCode: 403,
            body: '',
            invalidKeyStatusCodes: const {400, 403},
          ),
          contains('invalide'),
        );
        // 401 n'est pas dans le set personnalisé : reste le générique HTTP,
        // pas le message "clé invalide".
        expect(
          llmApiErrorMessage(
            providerName: 'Google AI',
            statusCode: 401,
            body: '',
            invalidKeyStatusCodes: const {400, 403},
          ),
          isNot(contains('invalide')),
        );
      },
    );

    test('statut inconnu sans corps exploitable : message HTTP générique', () {
      final message = llmApiErrorMessage(
        providerName: 'OpenAI',
        statusCode: 500,
        body: '',
      );

      expect(message, 'OpenAI a répondu HTTP 500.');
    });

    test('corps JSON sans clé error.message : retombe sur le générique', () {
      final message = llmApiErrorMessage(
        providerName: 'OpenAI',
        statusCode: 429,
        body: jsonEncode({'foo': 'bar'}),
      );

      expect(message, contains('Quota OpenAI'));
    });
  });
}
