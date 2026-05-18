// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> launchAppsScriptSync(String url) async {
  final iframe = html.IFrameElement()
    ..src = url
    ..style.display = 'none';

  html.document.body?.append(iframe);

  Future<void>.delayed(const Duration(seconds: 30), () {
    iframe.remove();
  });
}
