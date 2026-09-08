/// Backend desktop des prédicats de plateforme : délègue aux `Platform.is*`
/// de `dart:io`, comme le faisait l'ancien code — sémantique identique y
/// compris sous `flutter_tester`, où `Platform.isMacOS` reflète bien le host
/// (contrairement à `defaultTargetPlatform`, toujours `android`).
library;

import 'dart:io' show Platform;

bool get isMacOS => Platform.isMacOS;

bool get isWindows => Platform.isWindows;

bool get isLinux => Platform.isLinux;

bool get isIOS => Platform.isIOS;

bool get isAndroid => Platform.isAndroid;