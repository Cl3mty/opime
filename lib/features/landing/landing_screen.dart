import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme_controller.dart';
import '../../core/ui/app_background.dart';
import '../../core/ui/frosted_card.dart';
import '../../core/ui/responsive.dart';
import '../../core/updates/platform_asset_matcher.dart';
import '../../l10n/app_localizations.dart';

const _githubRepoUrl = 'https://github.com/Cl3mty/opime-free';

/// Catégorie "Idées" des GitHub Discussions du dépôt — vote natif (▲, voir
/// `.github/DISCUSSION_TEMPLATE/ideas.yml`) plutôt qu'une simple liste
/// d'issues : c'est le mécanisme de vote communautaire de fonctionnalités
/// choisi pour Opime.
const _githubIdeasUrl =
    'https://github.com/Cl3mty/opime-free/discussions/categories/ideas';
const _githubLatestReleaseUrl =
    'https://github.com/Cl3mty/opime-free/releases/latest';
const _githubLatestReleaseApiUrl =
    'https://api.github.com/repos/Cl3mty/opime-free/releases/latest';

/// Logo Opime — même asset et même traitement (coins arrondis, `BoxFit
/// .cover`) que la vignette de la sidebar (voir `app_sidebar.dart`), pour
/// que la vitrine et l'app affichent la même identité visuelle plutôt qu'une
/// icône générique.
class _Logo extends StatelessWidget {
  final double size;

  const _Logo({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/icon/icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Page de présentation ("landing page") du web : première chose qu'un
/// visiteur voit en arrivant sur le site, avant même l'écran de création de
/// coffre-fort. Purement présentationnelle — aucune dépendance vers le
/// stockage/vault, uniquement un rappel vers l'appelant pour rejoindre le
/// flux normal de l'app (voir `main.dart`'s `_buildHome`, qui ne l'affiche
/// que sur le web et tant qu'aucun coffre-fort n'a encore été créé sur cet
/// appareil : un utilisateur qui revient avec un coffre-fort existant
/// retombe directement dans l'app, sans repasser par cette vitrine).
class LandingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final ThemeController themeController;

  const LandingScreen({
    super.key,
    required this.onGetStarted,
    required this.themeController,
  });

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _featuresKey = GlobalKey();
  final _downloadKey = GlobalKey();

  void _scrollToFeatures() => _scrollTo(_featuresKey);

  void _scrollToDownload() => _scrollTo(_downloadKey);

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Enveloppe [child] dans la colonne étroite (1140px max, centrée) que
  /// partagent toutes les sections SAUF Fonctionnalités — celle-ci a son
  /// propre fond en pleine largeur (voir [_FeaturesSection]), donc son
  /// contenu se centre lui-même dans la même largeur indépendamment.
  Widget _narrow(bool wide, Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1140),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = isWideLayout(context);

    return Scaffold(
      child: AppBackground(
        child: Stack(
          children: [
            const Positioned.fill(child: IgnorePointer(child: _DotGrid())),
            SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _TopBar(
                      onGetStarted: widget.onGetStarted,
                      onDownload: _scrollToDownload,
                      themeController: widget.themeController,
                      l10n: l10n,
                    ),
                    _narrow(
                      wide,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: wide ? 64 : 36),
                          _Hero(
                            l10n: l10n,
                            onPrimary: widget.onGetStarted,
                            onSecondary: _scrollToFeatures,
                          ),
                          SizedBox(height: wide ? 56 : 40),
                          _FadeSlideIn(
                            delay: const Duration(milliseconds: 200),
                            child: _AppMockup(
                              themeController: widget.themeController,
                            ),
                          ),
                          SizedBox(height: wide ? 96 : 64),
                          _StatsBand(l10n: l10n, wide: wide),
                          // Sans cet espace, la dernière ligne des stats
                          // touchait directement la bordure supérieure de
                          // la bande Fonctionnalités juste en dessous (voir
                          // [_FeaturesSection]) — même remarque que la
                          // marge intérieure de cette dernière, mais côté
                          // extérieur, sur le fond normal de la page.
                          SizedBox(height: wide ? 96 : 64),
                        ],
                      ),
                    ),
                    // Fond distinct de la bande héro/stats/reste de la page
                    // (voir [_FeaturesSection]) : la section Fonctionnalités
                    // gère donc elle-même son espacement vertical (padding
                    // interne) plutôt que les `SizedBox` utilisés entre les
                    // autres sections, toutes sur le même fond.
                    _FeaturesSection(key: _featuresKey, l10n: l10n, wide: wide),
                    _narrow(
                      wide,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: wide ? 96 : 64),
                          _DownloadSection(
                            key: _downloadKey,
                            l10n: l10n,
                            onGetStarted: widget.onGetStarted,
                          ),
                          SizedBox(height: wide ? 96 : 64),
                        ],
                      ),
                    ),
                    _CommunitySection(
                      l10n: l10n,
                      wide: wide,
                      onVote: () => _openUrl(_githubIdeasUrl),
                    ),
                    _narrow(
                      wide,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: wide ? 64 : 48),
                          _Footer(
                            l10n: l10n,
                            onGithub: () => _openUrl(_githubRepoUrl),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trame de points très discrète derrière toute la page — donne un peu de
/// texture à [AppBackground] (qui reste, lui, un simple dégradé plat) sans
/// jamais distraire du contenu. Purement décoratif, ne réagit à aucune
/// interaction (`IgnorePointer` posé par l'appelant).
class _DotGrid extends StatelessWidget {
  const _DotGrid();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.foreground;
    return CustomPaint(painter: _DotGridPainter(color: color));
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;

  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 28.0;
    final paint = Paint()..color = color.withValues(alpha: 0.05);
    for (var y = 0.0; y < size.height; y += spacing) {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _TopBar extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onDownload;
  final ThemeController themeController;
  final AppLocalizations l10n;

  const _TopBar({
    required this.onGetStarted,
    required this.onDownload,
    required this.themeController,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sur les petites largeurs, la barre se resserre : on bascule les
    // boutons secondaires (bascule de thème et lien "Télécharger") vers une
    // icône seule et on masque leur libellé, pour toujours garder de la
    // place au CTA complet ("Ouvrir l'application").
    final compact = MediaQuery.sizeOf(context).width <= kWideLayoutBreakpoint;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        // Fond plein (plutôt que transparent) : sans lui, la trame de
        // points décorative de toute la page (voir [_DotGrid]) se serait
        // vue au travers de la barre du haut, seule zone où elle ne doit
        // jamais apparaître.
        color: theme.colorScheme.background,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          const _Logo(size: 30),
          const SizedBox(width: 10),
          const Text('Opime').semiBold().large(),
          const Spacer(),
          // Bascule clair/sombre : la navigation hérite du mode système au
          // premier chargement, ce bouton permet au visiteur de forcer
          // l'affichage qui lui convient sans quitter le flux de la vitrine.
          // En mode "système", on raisonne sur la luminosité effective (même
          // règle que `main.dart`) pour proposer la bascule la plus attendue.
          AnimatedBuilder(
            animation: themeController,
            builder: (context, _) {
              final isDark = switch (themeController.mode) {
                ThemeMode.light => false,
                ThemeMode.dark => true,
                ThemeMode.system =>
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark,
              };
              return GhostButton(
                onPressed: themeController.toggleLightDark,
                leading: Icon(
                  isDark ? LucideIcons.sun : LucideIcons.moon,
                  size: 15,
                ),
                child: compact
                    ? const SizedBox.shrink()
                    : Text(
                        isDark
                            ? l10n.landing_nav_theme_light
                            : l10n.landing_nav_theme_dark,
                      ),
              );
            },
          ),
          const SizedBox(width: 8),
          GhostButton(
            onPressed: onDownload,
            leading: const Icon(LucideIcons.download, size: 15),
            child: Text(l10n.landing_nav_download),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            onPressed: onGetStarted,
            trailing: const Icon(LucideIcons.arrowRight, size: 16),
            child: Text(l10n.landing_nav_cta),
          ),
        ],
      ),
    );
  }
}

/// Halo doux et lent derrière le titre — le seul accent "animé" de la page :
/// un dégradé radial qui dérive très légèrement, pour donner une impression
/// vivante sans tomber dans l'effet "néon" hors de la charte de l'app (voir
/// [AppBackground], dont ce halo n'est qu'une variation locale, plus marquée,
/// réservée à la zone héro).
class _HeroGlow extends StatefulWidget {
  const _HeroGlow();

  @override
  State<_HeroGlow> createState() => _HeroGlowState();
}

class _HeroGlowState extends State<_HeroGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Align(
            alignment: Alignment(0.15 * math.sin(t * math.pi * 2), -0.6),
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.22),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Fait apparaître [child] en fondu + léger glissement vers le haut, avec un
/// délai avant de démarrer — utilisé pour faire arriver les sections de la
/// page les unes après les autres plutôt que toutes d'un coup à l'ouverture.
class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _FadeSlideIn({required this.child, this.delay = Duration.zero});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _Hero({
    required this.l10n,
    required this.onPrimary,
    required this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final text = Column(
      children: [
        _FadeSlideIn(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              l10n.landing_hero_eyebrow,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: Text(
            l10n.landing_hero_title,
            textAlign: TextAlign.center,
          ).x6Large().bold(),
        ),
        const SizedBox(height: 20),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 160),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              l10n.landing_hero_subtitle,
              textAlign: TextAlign.center,
            ).large().muted(),
          ),
        ),
        const SizedBox(height: 32),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              PrimaryButton(
                onPressed: onPrimary,
                trailing: const Icon(LucideIcons.arrowRight, size: 16),
                child: Text(l10n.landing_hero_cta_primary),
              ),
              OutlineButton(
                onPressed: onSecondary,
                child: Text(l10n.landing_hero_cta_secondary),
              ),
            ],
          ),
        ),
      ],
    );

    return Stack(
      alignment: Alignment.topCenter,
      // `Clip.none` : par défaut, un `Stack` rogne tout ce qui dépasse de
      // ses propres limites — le halo flouté ci-dessous (voir
      // `_HeroGlow`) s'y voyait donc coupé net au lieu de s'estomper
      // progressivement.
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          top: -160,
          child: SizedBox(width: 640, height: 640, child: _HeroGlow()),
        ),
        text,
      ],
    );
  }
}

/// Les 4 vraies captures d'écran de l'application en thème sombre (macOS,
/// redimensionnées pour le poids du bundle web) utilisées dans le carousel
/// du héro — une tentative précédente de reconstitution en widgets
/// n'atteignait jamais la fidélité d'une vraie capture ; celles-ci sont les
/// écrans réels de l'app, dans l'ordre Tableau de bord / Projets / Budget
/// (Ventilation) / Simulation (Patrimoine). Voir [_appScreenshotsLight] pour
/// l'équivalent en thème clair.
const _appScreenshots = [
  'assets/landing/screenshot_dashboard.png',
  'assets/landing/screenshot_projects.png',
  'assets/landing/screenshot_budget.png',
  'assets/landing/screenshot_simulation.png',
];

/// Mêmes écrans, capturés en thème clair — utilisés à la place des captures
/// sombres ci-dessus quand la bascule clair/sombre de la vitrine (voir
/// [_TopBar]) résout à un thème clair, pour que le carousel reflète toujours
/// l'apparence réelle de l'app plutôt qu'un seul thème figé.
const _appScreenshotsLight = [
  'assets/landing/screenshot_dashboard_light.png',
  'assets/landing/screenshot_projects_light.png',
  'assets/landing/screenshot_budget_light.png',
  'assets/landing/screenshot_simulation_light.png',
];

/// Ratio des captures sources (1800×1130 après redimensionnement ET
/// recadrage de la fine bande noire résiduelle de la barre de titre macOS
/// réelle en haut de la capture — sans ce recadrage, elle s'ajoutait à la
/// fausse barre de titre déjà dessinée par [_MacWindowTitleBar], donnant
/// l'impression de deux barres empilées ; voir `assets/landing/`) : une
/// [AspectRatio] fixe garantit un cadrage identique aux 4 diapositives
/// plutôt qu'un saut de hauteur au changement.
const _screenshotAspectRatio = 1800 / 1130;

/// Vrai carousel de captures d'écran de l'app, avec défilement automatique
/// (voir [_scheduleAutoPlay]) — toute navigation manuelle (flèches, puces,
/// glissement tactile du `PageView`) relance simplement le minuteur plutôt
/// que d'entrer en conflit avec lui.
class _AppMockup extends StatefulWidget {
  final ThemeController themeController;

  const _AppMockup({required this.themeController});

  @override
  State<_AppMockup> createState() => _AppMockupState();
}

class _AppMockupState extends State<_AppMockup> {
  static const _autoPlayInterval = Duration(seconds: 5);

  late final PageController _pageController = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleAutoPlay();
  }

  void _scheduleAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoPlayInterval, (_) => _goTo(_index + 1));
  }

  void _goTo(int index) {
    final target = index % _appScreenshots.length;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    _scheduleAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.themeController,
      builder: (context, _) {
        final isDark = switch (widget.themeController.mode) {
          ThemeMode.light => false,
          ThemeMode.dark => true,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        final screenshots = isDark ? _appScreenshots : _appScreenshotsLight;
        return FrostedCard(
          child: Column(
            children: [
              _MacWindowTitleBar(isDark: isDark),
              AspectRatio(
                aspectRatio: _screenshotAspectRatio,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: screenshots.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) =>
                      Image.asset(screenshots[index], fit: BoxFit.cover),
                ),
              ),
              _CarouselControls(
                count: screenshots.length,
                index: _index,
                onPrevious: () => _goTo(_index - 1),
                onNext: () => _goTo(_index + 1),
                onSelect: _goTo,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barre de titre "façon macOS" ajoutée au-dessus de chaque capture — 3
/// pastilles rouge/jaune/vert purement décoratives (comme sur un vrai
/// macOS, leur couleur ne dépend pas du thème), pour rendre le carousel
/// plus immersif (un vrai contour de fenêtre) sans dupliquer de chrome :
/// les captures elles-mêmes sont recadrées pour ne montrer que le contenu
/// de l'app, sans barre de titre ni menu système macOS. Les angles
/// arrondis viennent du [ClipRRect] déjà posé par [FrostedCard] autour de
/// tout le carousel, pas d'un radius propre à cette barre. [isDark] suit le
/// thème choisi sur la vitrine (voir [_AppMockupState]) : un vrai macOS a
/// aussi une barre de titre claire/sombre selon son thème, cette barre
/// resterait sinon incongrue (sombre) au-dessus d'une capture d'app claire.
class _MacWindowTitleBar extends StatelessWidget {
  final bool isDark;

  const _MacWindowTitleBar({required this.isDark});

  static const _dotColors = [
    Color(0xFFFF5F57),
    Color(0xFFFEBC2E),
    Color(0xFF28C840),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE4E4E4),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _dotColors.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: _dotColors[i],
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Flèches + puces sous le carousel — la seule affordance de navigation
/// visible sans souris à disposition (le glissement tactile du `PageView`
/// marche aussi, mais n'est pas visible), et le moyen d'interrompre/relancer
/// le défilement automatique (voir [_AppMockupState._scheduleAutoPlay]).
class _CarouselControls extends StatelessWidget {
  final int count;
  final int index;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onSelect;

  const _CarouselControls({
    required this.count,
    required this.index,
    required this.onPrevious,
    required this.onNext,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.border.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CarouselArrowButton(
            icon: LucideIcons.chevronLeft,
            onTap: onPrevious,
          ),
          const SizedBox(width: 14),
          for (var i = 0; i < count; i++)
            GestureDetector(
              key: ValueKey('landing_carousel_dot_$i'),
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == index ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.mutedForeground.withValues(
                          alpha: 0.35,
                        ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          const SizedBox(width: 14),
          _CarouselArrowButton(icon: LucideIcons.chevronRight, onTap: onNext),
        ],
      ),
    );
  }
}

class _CarouselArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CarouselArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.border.withValues(alpha: 0.6),
          ),
        ),
        child: Icon(icon, size: 14, color: theme.colorScheme.foreground),
      ),
    );
  }
}

class _StatData {
  final String label;
  final String description;

  const _StatData(this.label, this.description);
}

/// Bandeau "100 % x3" — la promesse centrale de l'app affichée en gros
/// juste après le héro, plutôt que noyée plus bas dans de petits badges :
/// les données restent à l'utilisateur, l'app est gratuite, et soignée.
class _StatsBand extends StatelessWidget {
  final AppLocalizations l10n;
  final bool wide;

  const _StatsBand({required this.l10n, required this.wide});

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatData(
        l10n.landing_stat_data_label,
        l10n.landing_stat_data_description,
      ),
      _StatData(
        l10n.landing_stat_free_label,
        l10n.landing_stat_free_description,
      ),
      _StatData(
        l10n.landing_stat_modern_label,
        l10n.landing_stat_modern_description,
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 20,
      runSpacing: 24,
      children: [
        for (var i = 0; i < stats.length; i++)
          _FadeSlideIn(
            delay: Duration(milliseconds: 80 * i),
            child: SizedBox(
              width: wide ? 320 : double.infinity,
              child: _StatCallout(stat: stats[i]),
            ),
          ),
      ],
    );
  }
}

class _StatCallout extends StatelessWidget {
  final _StatData stat;

  const _StatCallout({required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '100%',
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(stat.label, textAlign: TextAlign.center).semiBold().medium(),
        const SizedBox(height: 4),
        Text(stat.description, textAlign: TextAlign.center).small().muted(),
      ],
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureData(this.icon, this.title, this.description);
}

/// Bande pleine largeur à fond teinté, distinct du reste de la page — une
/// simple teinte (plutôt qu'un motif ou dégradé propre) suffit à démarquer
/// visuellement une section de ses voisines, toutes sur le fond de
/// [AppBackground]. Partagée par [_FeaturesSection] et [_CommunitySection]
/// pour que la page alterne fond neutre / fond teinté de façon cohérente au
/// lieu de n'isoler qu'une seule section. Le contenu ([child]) reste centré
/// dans la même largeur (1140px) que les autres sections malgré ce fond en
/// pleine largeur.
class _TintedBand extends StatelessWidget {
  final bool wide;
  final Widget child;

  const _TintedBand({required this.wide, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.colorScheme.background.computeLuminance() < 0.5;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // `muted` plutôt que `card` : en thème sombre, `card` a exactement
        // la même luminosité que le fond de page (même motif que
        // `FrostedCard`, voir sa documentation) et ne créerait donc aucun
        // contraste visible.
        color: theme.colorScheme.muted.withValues(alpha: isDark ? 0.35 : 0.5),
        border: Border.symmetric(
          horizontal: BorderSide(
            color: theme.colorScheme.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: wide ? 96 : 64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool wide;

  const _FeaturesSection({super.key, required this.l10n, required this.wide});

  @override
  Widget build(BuildContext context) {
    return _TintedBand(
      wide: wide,
      child: _Features(l10n: l10n, wide: wide),
    );
  }
}

class _Features extends StatelessWidget {
  final AppLocalizations l10n;
  final bool wide;

  const _Features({required this.l10n, required this.wide});

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureData(
        LucideIcons.layoutDashboard,
        l10n.landing_feature_dashboard_title,
        l10n.landing_feature_dashboard_description,
      ),
      _FeatureData(
        LucideIcons.trendingUp,
        l10n.landing_feature_investments_title,
        l10n.landing_feature_investments_description,
      ),
      _FeatureData(
        LucideIcons.wallet,
        l10n.landing_feature_budget_title,
        l10n.landing_feature_budget_description,
      ),
      _FeatureData(
        LucideIcons.calculator,
        l10n.landing_feature_simulations_title,
        l10n.landing_feature_simulations_description,
      ),
      _FeatureData(
        LucideIcons.graduationCap,
        l10n.landing_feature_academy_title,
        l10n.landing_feature_academy_description,
      ),
      _FeatureData(
        LucideIcons.shieldCheck,
        l10n.landing_feature_privacy_title,
        l10n.landing_feature_privacy_description,
      ),
    ];

    final cardWidth = wide ? 320.0 : double.infinity;

    return Column(
      children: [
        _FadeSlideIn(
          child: Text(
            l10n.landing_features_title,
            textAlign: TextAlign.center,
          ).x3Large().bold(),
        ),
        const SizedBox(height: 12),
        _FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: Text(
            l10n.landing_features_subtitle,
            textAlign: TextAlign.center,
          ).large().muted(),
        ),
        const SizedBox(height: 40),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 20,
          children: [
            for (var i = 0; i < features.length; i++)
              _FadeSlideIn(
                delay: Duration(milliseconds: 100 * i),
                child: SizedBox(
                  width: cardWidth,
                  child: _FeatureCard(feature: features[i]),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Carte de fonctionnalité avec un léger effet de survol (translation vers
/// le haut + bordure plus marquée) — un site web se manipule à la souris,
/// contrairement au reste de l'app pensée tactile/desktop sans survol ;
/// `MouseRegion` ne se déclenche de toute façon jamais sur un appareil
/// tactile, donc sans risque ailleurs.
class _FeatureCard extends StatefulWidget {
  final _FeatureData feature;

  const _FeatureCard({required this.feature});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovered ? -4 : 0, 0),
        height: 180,
        child: FrostedCard(
          expand: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(theme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? theme.colorScheme.primary.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Icon(
                      widget.feature.icon,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.feature.title).semiBold().large(),
                  const SizedBox(height: 6),
                  Text(widget.feature.description).small().muted(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Systèmes d'exploitation desktop proposés au téléchargement — pas Web ni
/// mobile.
enum _DesktopOs { macos, windows, linux }

/// Détecté une seule fois par instance (voir [_DownloadSectionState]) via
/// [defaultTargetPlatform] : sur le web, Flutter le déduit de l'appareil
/// hôte du navigateur (`navigator.platform`), pas du serveur — c'est
/// justement ce qu'on veut ici, contrairement à `core/platform_info.dart`'s
/// `isMacOS`/`isWindows`/`isLinux`, délibérément câblés à `!kIsWeb` pour un
/// tout autre usage (fonctionnalités natives réellement indisponibles dans
/// un navigateur). `null` si l'appareil détecté n'est ni macOS, ni Windows,
/// ni Linux (mobile, ou détection indisponible) — aucun favori proposé,
/// seulement le lien générique vers toutes les versions.
_DesktopOs? _detectDesktopOs() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.macOS => _DesktopOs.macos,
    TargetPlatform.windows => _DesktopOs.windows,
    TargetPlatform.linux => _DesktopOs.linux,
    _ => null,
  };
}

String _desktopOsLabel(_DesktopOs os) => switch (os) {
  _DesktopOs.macos => 'macOS',
  _DesktopOs.windows => 'Windows',
  _DesktopOs.linux => 'Linux',
};

IconData _desktopOsIcon(_DesktopOs os) => switch (os) {
  _DesktopOs.macos => LucideIcons.apple,
  _DesktopOs.windows => LucideIcons.monitor,
  _DesktopOs.linux => LucideIcons.monitor,
};

/// Interroge la dernière release GitHub une seule fois et en tire le lien de
/// téléchargement direct pour chaque OS desktop (même correspondance de nom
/// de fichier que [UpdateChecker], voir `platform_asset_matcher.dart`) —
/// `null` par entrée si cette release n'a pas (encore) d'installeur pour cet
/// OS, ou si la requête échoue (pas de connexion, limite de débit
/// GitHub...), auquel cas l'appelant retombe sur le lien générique vers la
/// page des releases plutôt que de laisser un bouton mort.
Future<Map<_DesktopOs, String?>> _fetchDesktopDownloadUrls() async {
  try {
    final response = await http
        .get(
          Uri.parse(_githubLatestReleaseApiUrl),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return {};
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final assets = (json['assets'] as List?) ?? [];
    return {
      for (final os in _DesktopOs.values)
        os: pickPlatformAssetDownloadUrl(
          assets,
          isMacOS: os == _DesktopOs.macos,
          isWindows: os == _DesktopOs.windows,
          isLinux: os == _DesktopOs.linux,
        ),
    };
  } catch (_) {
    // Web hors ligne, requête bloquée, limite de débit GitHub atteinte...
    // jamais bloquant : le bouton retombe simplement sur le lien générique
    // vers les releases (voir [_DownloadSectionState.build]).
    return {};
  }
}

/// Section "Télécharger" — propose en avant le logiciel de bureau pour l'OS
/// détecté ([_detectDesktopOs]), avec les deux autres OS desktop en options
/// secondaires, plutôt qu'un unique lien générique vers les releases.
/// Regroupe aussi l'alternative "directement dans le navigateur"
/// ([widget.onGetStarted]) dans la même carte plutôt que dans une section
/// séparée redondante : les deux sont la même décision ("comment démarrer
/// avec Opime ?"), pas deux sujets distincts.
class _DownloadSection extends StatefulWidget {
  final AppLocalizations l10n;
  final VoidCallback onGetStarted;

  const _DownloadSection({
    super.key,
    required this.l10n,
    required this.onGetStarted,
  });

  @override
  State<_DownloadSection> createState() => _DownloadSectionState();
}

class _DownloadSectionState extends State<_DownloadSection> {
  final _detectedOs = _detectDesktopOs();
  late final Future<Map<_DesktopOs, String?>> _downloadUrls =
      _fetchDesktopDownloadUrls();

  Future<void> _openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = widget.l10n;
    final detected = _detectedOs ?? _DesktopOs.macos;
    final otherOs = _DesktopOs.values.where((os) => os != detected).toList();

    return _FadeSlideIn(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: FutureBuilder<Map<_DesktopOs, String?>>(
                future: _downloadUrls,
                builder: (context, snapshot) {
                  final urls = snapshot.data ?? const {};
                  final loading =
                      snapshot.connectionState == ConnectionState.waiting;
                  final primaryUrl = urls[detected] ?? _githubLatestReleaseUrl;

                  return Column(
                    children: [
                      Icon(
                        _desktopOsIcon(detected),
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.landing_download_title(_desktopOsLabel(detected)),
                        textAlign: TextAlign.center,
                      ).x2Large().bold(),
                      const SizedBox(height: 8),
                      Text(
                        l10n.landing_download_subtitle,
                        textAlign: TextAlign.center,
                      ).muted(),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        onPressed: () => _openUrl(primaryUrl),
                        leading: loading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(_desktopOsIcon(detected), size: 16),
                        child: Text(
                          l10n.landing_download_button(
                            _desktopOsLabel(detected),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final os in otherOs)
                            GhostButton(
                              onPressed: () =>
                                  _openUrl(urls[os] ?? _githubLatestReleaseUrl),
                              trailing: const Icon(
                                LucideIcons.arrowUpRight,
                                size: 13,
                              ),
                              child: Text(
                                l10n.landing_download_other(
                                  _desktopOsLabel(os),
                                ),
                              ),
                            ),
                          GhostButton(
                            onPressed: () => _openUrl(_githubLatestReleaseUrl),
                            trailing: const Icon(
                              LucideIcons.arrowUpRight,
                              size: 13,
                            ),
                            child: Text(l10n.landing_download_all_versions),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              l10n.landing_or_divider,
                            ).xSmall().muted(),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.landing_final_cta_subtitle,
                        textAlign: TextAlign.center,
                      ).small().muted(),
                      const SizedBox(height: 12),
                      OutlineButton(
                        onPressed: widget.onGetStarted,
                        trailing: const Icon(LucideIcons.arrowRight, size: 16),
                        child: Text(l10n.landing_final_cta_button),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Community extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onVote;

  const _Community({required this.l10n, required this.onVote});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _FadeSlideIn(
      // Une carte qui garde la pleine largeur de la page pour un simple bloc
      // de texte centré se retrouve avec un vide disproportionné de chaque
      // côté — la carte est resserrée autour de son contenu plutôt
      // qu'étirée sur toute la largeur disponible.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FrostedCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.github,
                    color: theme.colorScheme.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.landing_community_title,
                    textAlign: TextAlign.center,
                  ).x2Large().bold(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.landing_community_subtitle,
                    textAlign: TextAlign.center,
                  ).muted(),
                  const SizedBox(height: 24),
                  OutlineButton(
                    onPressed: onVote,
                    trailing: const Icon(LucideIcons.arrowUpRight, size: 16),
                    child: Text(l10n.landing_community_cta),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bande pleine largeur portant la section Communauté sur un fond teinté —
/// voir [_TintedBand] : la page alterne ainsi fond neutre (héro,
/// Télécharger) et fond teinté (Fonctionnalités, Communauté) plutôt que de
/// n'isoler qu'une seule section de cette façon.
class _CommunitySection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool wide;
  final VoidCallback onVote;

  const _CommunitySection({
    required this.l10n,
    required this.wide,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return _TintedBand(
      wide: wide,
      child: _Community(l10n: l10n, onVote: onVote),
    );
  }
}

class _Footer extends StatelessWidget {
  final AppLocalizations l10n;
  final VoidCallback onGithub;

  const _Footer({required this.l10n, required this.onGithub});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GhostButton(
          onPressed: onGithub,
          leading: const Icon(LucideIcons.github, size: 16),
          child: Text(l10n.landing_footer_github),
        ),
        const SizedBox(height: 4),
        Text(l10n.landing_footer_tagline).small().muted(),
      ],
    );
  }
}
