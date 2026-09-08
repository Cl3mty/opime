import 'package:flutter/foundation.dart';

/// Signale, à l'échelle de l'app, si la dernière tentative de
/// synchronisation d'un cours (voir `PriceHistoryRepository.syncIfNeeded`)
/// a échoué pour une raison réseau (hors ligne, API Yahoo Finance
/// injoignable) — distinct d'un identifiant simplement non résolu (par ex.
/// les métaux précieux, dont le ticker Yahoo Finance est difficile à
/// déduire automatiquement : un problème connu, à traiter plus tard, qui
/// ne doit pas être confondu avec une coupure réseau).
///
/// Chaque investissement synchronise son cours indépendamment (à
/// l'ouverture de sa page), mais l'utilisateur n'a besoin de voir qu'un
/// seul indicateur centralisé plutôt qu'un bandeau répété sur chaque
/// investissement — voir `PriceSyncBanner`.
class PriceSyncStatusController extends ChangeNotifier {
  bool _offline = false;
  bool get offline => _offline;

  void reportOffline() {
    if (_offline) return;
    _offline = true;
    notifyListeners();
  }

  void reportOnline() {
    if (!_offline) return;
    _offline = false;
    notifyListeners();
  }
}
