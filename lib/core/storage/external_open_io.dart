import 'package:url_launcher/url_launcher.dart' as ul;

/// Desktop : on ouvre le fichier matérialisé avec l'app par défaut du
/// système (`Preview.app`, Adobe, etc.).
Future<void> openExternalFile(String path) async {
  await ul.launchUrl(Uri.file(path), mode: ul.LaunchMode.externalApplication);
}