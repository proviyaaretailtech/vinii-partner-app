import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/script_fonts.dart';

/// The line printed under a code when the caller does not pass its own. The
/// screen passes the line in the app's language (`tableCardScan`); this is
/// only the English fallback for tests and code that has no l10n at hand.
// i18n-ignore: English fallback; the screen passes the translated line
const defaultScanLine = 'Scan to see the menu and order';

/// One centred line (or two) of the card, laid out and ready to paint. Inter
/// has no Devanagari glyphs, so every style lists the script fallback font:
/// a Hindi table name or tagline is drawn with Flutter's own text engine, which
/// shapes it correctly (the `pdf` package cannot, which is why the printed
/// sheet embeds this picture instead of drawing words itself).
TextPainter _laidOut(
  String text,
  TextStyle style, {
  required int lines,
  required double maxWidth,
}) => TextPainter(
  text: TextSpan(text: text, style: style),
  textAlign: TextAlign.center,
  textDirection: TextDirection.ltr,
  maxLines: lines,
  ellipsis: '…',
)..layout(maxWidth: maxWidth);

void _paintCentered(ui.Canvas canvas, TextPainter p, double width, double y) =>
    p.paint(canvas, Offset((width - p.width) / 2, y));

/// The picture of one table's code: the QR on white with the table's name and
/// the restaurant's name under it. It is what "Save image" downloads and what
/// "Print all" puts on the sheet, so a printed card and a saved picture are
/// the same thing.
///
/// Level M error correction survives a smudged or half-covered sticker, and
/// the white margin around the code is the quiet zone scanners need.
///
/// The card grows taller when the words need more room (Hindi lines are
/// taller than English ones); with short words it is the usual 1200 x 1560.
Future<Uint8List> renderTableCardPng({
  required String link,
  required String tableName,
  required String restaurant,
  String scanLine = defaultScanLine,
}) async {
  const w = 1200.0;
  const qrSize = 920.0;
  const qrTop = 130.0;
  const textWidth = w - 160;

  final name = _laidOut(
    tableName,
    const TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: kScriptFontFallback,
      fontSize: 116,
      fontWeight: FontWeight.w800,
      color: Color(0xFF111115),
      height: 1.25,
    ),
    lines: 1,
    maxWidth: textWidth,
  );
  final shop = _laidOut(
    restaurant,
    const TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: kScriptFontFallback,
      fontSize: 58,
      fontWeight: FontWeight.w600,
      color: Color(0xFF555560),
      height: 1.3,
    ),
    lines: 2,
    maxWidth: textWidth,
  );
  final scan = _laidOut(
    scanLine,
    const TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: kScriptFontFallback,
      fontSize: 44,
      color: Color(0xFF94969E),
      height: 1.3,
    ),
    lines: 2,
    maxWidth: textWidth,
  );

  final nameY = qrTop + qrSize + 70;
  final shopY = nameY + name.height + 14;
  final scanY = shopY + shop.height + 22;
  final h = math.max(1560.0, scanY + scan.height + 70);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w, h));

  final card = RRect.fromRectAndRadius(
    Rect.fromLTWH(0, 0, w, h),
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
  canvas.translate((w - qrSize) / 2, qrTop);
  qr.paint(canvas, const Size(qrSize, qrSize));
  canvas.restore();

  _paintCentered(canvas, name, w, nameY);
  _paintCentered(canvas, shop, w, shopY);
  _paintCentered(canvas, scan, w, scanY);

  final image = await recorder.endRecording().toImage(w.toInt(), h.ceil());
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
  String scanLine = defaultScanLine,
}) async {
  const w = 600.0;
  const textWidth = w - 20;

  final name = _laidOut(
    tableName,
    const TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: kScriptFontFallback,
      fontSize: 84,
      fontWeight: FontWeight.w800,
      color: Color(0xFF111115),
      height: 1.25,
    ),
    lines: 1,
    maxWidth: textWidth,
  );
  final shop = _laidOut(
    restaurant,
    const TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: kScriptFontFallback,
      fontSize: 42,
      fontWeight: FontWeight.w600,
      color: Color(0xFF555560),
      height: 1.3,
    ),
    lines: 2,
    maxWidth: textWidth,
  );
  final scan = _laidOut(
    scanLine,
    const TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: kScriptFontFallback,
      fontSize: 32,
      color: Color(0xFF777782),
      height: 1.3,
    ),
    lines: 2,
    maxWidth: textWidth,
  );

  final shopY = name.height;
  final scanY = shopY + shop.height;
  final h = (scanY + scan.height + 8).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  _paintCentered(canvas, name, w, 0);
  _paintCentered(canvas, shop, w, shopY);
  _paintCentered(canvas, scan, w, scanY);

  final image = await recorder.endRecording().toImage(w.toInt(), h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
