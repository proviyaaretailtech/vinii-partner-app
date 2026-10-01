import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// The picture of one table's code: the QR on white with the table's name and
/// the restaurant's name under it. It is what "Save image" downloads and what
/// "Print all" puts on the sheet, so a printed card and a saved picture are
/// the same thing.
///
/// Level M error correction survives a smudged or half-covered sticker, and
/// the white margin around the code is the quiet zone scanners need.
Future<Uint8List> renderTableCardPng({
  required String link,
  required String tableName,
  required String restaurant,
}) async {
  const w = 1200.0;
  const h = 1560.0;
  const qrSize = 920.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, w, h));

  final card = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, w, h),
    const Radius.circular(56),
  );
  canvas.drawRRect(card, Paint()..color = const Color(0xFFFFFFFF));
  // A thin outline marks where to cut.
  canvas.drawRRect(
    card.deflate(3),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFFD5D7DD),
  );

  final qr = QrPainter(
    data: link,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
  );
  canvas.save();
  canvas.translate((w - qrSize) / 2, 130);
  qr.paint(canvas, const Size(qrSize, qrSize));
  canvas.restore();

  double drawCentered(String text, double y, TextStyle style, {int lines = 2}) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: w - 160);
    p.paint(canvas, Offset((w - p.width) / 2, y));
    return y + p.height;
  }

  var y = 130 + qrSize + 70;
  y = drawCentered(
    tableName,
    y,
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 116,
      fontWeight: FontWeight.w800,
      color: Color(0xFF111115),
      height: 1.1,
    ),
    lines: 1,
  );
  y = drawCentered(
    restaurant,
    y + 14,
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 58,
      fontWeight: FontWeight.w600,
      color: Color(0xFF555560),
      height: 1.2,
    ),
  );
  drawCentered(
    'Scan to see the menu and order',
    y + 22,
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 44,
      color: Color(0xFF94969E),
      height: 1.2,
    ),
    lines: 1,
  );

  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Just the words that go under a code on a printed sheet: the table's name,
/// the restaurant's name and a line saying what to do. The sheet draws the
/// code itself as sharp vector squares, and takes these words from here so
/// every script the phone can draw (Hindi and Marathi names included)
/// prints correctly. Small on purpose: building the sheet stays quick.
Future<Uint8List> renderTableLabelPng({
  required String tableName,
  required String restaurant,
}) async {
  const w = 600.0;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);

  var y = 0.0;
  double drawCentered(String text, TextStyle style, {int lines = 2}) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: lines,
      ellipsis: '…',
    )..layout(maxWidth: w - 20);
    p.paint(canvas, Offset((w - p.width) / 2, y));
    return y + p.height;
  }

  y = drawCentered(
    tableName,
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 84,
      fontWeight: FontWeight.w800,
      color: Color(0xFF111115),
      height: 1.1,
    ),
    lines: 1,
  );
  y = drawCentered(
    restaurant,
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 42,
      fontWeight: FontWeight.w600,
      color: Color(0xFF555560),
      height: 1.2,
    ),
  );
  y = drawCentered(
    'Scan to see the menu and order',
    const TextStyle(
      fontFamily: 'Inter',
      fontSize: 32,
      color: Color(0xFF777782),
      height: 1.2,
    ),
    lines: 1,
  );

  final image = await recorder.endRecording().toImage(
    w.toInt(),
    (y + 8).ceil(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
