import 'package:web/web.dart' as web;

void replaceUrlPath(String path) {
  web.window.history.replaceState(null, '', path);
}
