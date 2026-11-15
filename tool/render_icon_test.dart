// Renders the launcher icon PNGs from the SeeULogo painter.
//   flutter test tool/render_icon_test.dart && dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seeu/ui/logo.dart';

Future<void> render(WidgetTester tester, Widget logo, String path) async {
  final key = GlobalKey();
  await tester.pumpWidget(Center(child: RepaintBoundary(key: key, child: logo)));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render icons', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await render(tester, const SeeULogo(size: 1024, rounded: false), 'assets/icon/icon.png');
    // Adaptive icon foreground: transparent, content inside the 66 % safe zone.
    await render(tester, const SeeULogo(size: 1024, background: false, padding: 96), 'assets/icon/foreground.png');
  });
}
