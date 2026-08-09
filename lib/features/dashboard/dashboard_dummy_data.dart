/// Données d'exemple pour poser la structure visuelle du Dashboard, en
/// s'inspirant des captures Finary fournies — avant que le vrai module
/// Patrimoine (transactions, import, calcul de performance) existe. Un
/// seul point d'entrée ([dashboardSampleData]) : le futur repository
/// réel remplacera cette classe sans que les widgets aient à changer.
library;

/// Un point de la courbe de patrimoine net dans le temps.
class NetWorthPoint {
  final DateTime date;
  final double value;

  const NetWorthPoint(this.date, this.value);
}

/// Un actif affiché dans "Mes meilleurs actifs".
class DashboardAsset {
  final String name;
  final String ticker;
  final double changePercent;
  final List<double> sparkline;

  const DashboardAsset({
    required this.name,
    required this.ticker,
    required this.changePercent,
    required this.sparkline,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}

class DashboardSampleData {
  final List<NetWorthPoint> netWorthHistory;
  final List<DashboardAsset> topAssets;

  const DashboardSampleData({
    required this.netWorthHistory,
    required this.topAssets,
  });

  double get latestValue => netWorthHistory.last.value;

  /// Extrait la portion de [netWorthHistory] correspondant à une période
  /// (les N derniers points), sans jamais renvoyer moins de 2 points —
  /// un vrai repository ferait ça via une requête bornée par date.
  List<NetWorthPoint> sliceForDays(int days) {
    if (days >= netWorthHistory.length) return netWorthHistory;
    final start = (netWorthHistory.length - days).clamp(
      0,
      netWorthHistory.length - 2,
    );
    return netWorthHistory.sublist(start);
  }

  /// Plus-value en % entre le premier et le dernier point d'une période.
  double changePercentFor(List<NetWorthPoint> points) {
    if (points.length < 2 || points.first.value == 0) return 0;
    return (points.last.value - points.first.value) / points.first.value * 100;
  }
}

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

/// Environ 7 mois d'historique (un point par semaine), avec une légère
/// tendance haussière et un repli récent — même silhouette que les
/// courbes vues sur les captures Finary fournies.
final dashboardSampleData = DashboardSampleData(
  netWorthHistory: [
    _point(210, 231000),
    _point(203, 233500),
    _point(196, 235800),
    _point(189, 234200),
    _point(182, 238900),
    _point(175, 241300),
    _point(168, 240100),
    _point(161, 244600),
    _point(154, 247800),
    _point(147, 246200),
    _point(140, 249900),
    _point(133, 253400),
    _point(126, 252100),
    _point(119, 256700),
    _point(112, 259300),
    _point(105, 258000),
    _point(98, 261900),
    _point(91, 264500),
    _point(84, 263100),
    _point(77, 267800),
    _point(70, 270200),
    _point(63, 269400),
    _point(56, 272600),
    _point(49, 275100),
    _point(42, 273900),
    _point(35, 276800),
    _point(28, 274300),
    _point(21, 268900),
    _point(14, 264200),
    _point(7, 260800),
    _point(0, 258400),
  ],
  topAssets: [
    DashboardAsset(
      name: 'TotalEnergies SE',
      ticker: 'TTE',
      changePercent: 8.68,
      sparkline: [10, 11, 10.5, 12, 13, 12.5, 14, 15, 16, 18],
    ),
    DashboardAsset(
      name: 'Amundi PEA S&P 500',
      ticker: 'PE500',
      changePercent: 12.4,
      sparkline: [8, 8.5, 9, 8.7, 9.4, 10.1, 10.6, 11.2, 12, 13.1],
    ),
    DashboardAsset(
      name: 'BNP Paribas Easy',
      ticker: 'ESE',
      changePercent: 2.48,
      sparkline: [14, 13.6, 13.9, 13.7, 14.1, 13.9, 14.3, 14.2, 14.5, 14.4],
    ),
    DashboardAsset(
      name: 'Sopra Steria',
      ticker: 'SOP',
      changePercent: -4.32,
      sparkline: [22, 21.6, 21.8, 21, 20.4, 20.7, 19.9, 19.5, 19.2, 18.8],
    ),
    DashboardAsset(
      name: 'Bitcoin',
      ticker: 'BTC',
      changePercent: 30.45,
      sparkline: [5, 5.4, 5.2, 6, 6.8, 6.5, 7.4, 8.1, 7.9, 9],
    ),
  ],
);

NetWorthPoint _point(int daysAgo, double value) =>
    NetWorthPoint(_daysAgo(daysAgo), value);
