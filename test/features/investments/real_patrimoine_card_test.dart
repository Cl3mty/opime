import 'package:flutter_test/flutter_test.dart';
import 'package:opime/features/dashboard/patrimoine_models.dart';
import 'package:opime/features/investments/real_patrimoine_card.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets(
    'affiche la plus-value latente globale (montant signé + pourcentage) '
    'sous le changement de période, à partir de plusValueAbsPatrimoine',
    (tester) async {
      final category = PatrimoineCategory(
        id: 'actifs_actions_fonds',
        label: 'Actions & Fonds',
        icon: LucideIcons.trendingUp,
        color: const Color(0xFF000000),
        tier: AllocationTier.fondation,
        description: '',
        accounts: [
          const PatrimoineAccount(
            name: 'CTO',
            valeur: 1100,
            // 1100 investis pour un coût d'acquisition de 1000 : +10 %.
            plusValueAbs: 100,
            plusValuePercent: 10,
          ),
        ],
      );
      final history = [
        NetWorthPoint(DateTime(2026, 1, 1), 900),
        NetWorthPoint(DateTime(2026, 6, 1), 1100),
      ];

      await tester.pumpWidget(
        ShadcnApp(
          home: Scaffold(
            child: RealPatrimoineCard(
              actifs: [category],
              actifsHistoryFor: (_) => {category.id: history},
              totalPassifHistoryFor: (_) => const [],
              hidden: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Plus-value latente'), findsOneWidget);
      // `formatEuros` arrondit à l'euro (pas de décimales) ; `displayPercent`
      // garde 2 décimales avec un point (`toStringAsFixed`, pas de
      // formatage localisé) — voir `core/money_format.dart`.
      expect(find.textContaining('+100 €'), findsOneWidget);
      expect(find.textContaining('+10.00 %'), findsOneWidget);
    },
  );
}
