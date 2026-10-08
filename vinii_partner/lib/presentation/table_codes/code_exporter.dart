import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../core/failure.dart';
import 'download.dart';
import 'table_card_image.dart';
import 'table_sheet_pdf.dart';

/// One table's card: what its QR holds and the words printed under it.
class CodeCard {
  const CodeCard({
    required this.tableName,
    required this.restaurant,
    required this.link,
    this.scanLine = defaultScanLine,
    this.fileLabel,
  });

  /// The table's name in the reader's language ("Table 12" / "टेबल 12").
  final String tableName;
  final String restaurant;

  /// `<storefront address>/t/<code>`.
  final String link;

  /// What the guest is told to do, in the reader's language. It is printed on
  /// the card, so the screen passes the translated line.
  final String scanLine;

  /// What the picture's file name is built from. A file name is Latin letters
  /// and digits only, so it must not depend on the language the words on the
  /// card are in; defaults to [tableName].
  final String? fileLabel;

  /// "test-kitchen-table-12-qr.png"
  String get fileName {
    String slug(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final parts = [slug(restaurant), slug(fileLabel ?? tableName)]
      ..removeWhere((p) => p.isEmpty);
    // i18n-ignore: file name, Latin by design
    return '${parts.isEmpty ? 'table' : parts.join('-')}-qr.png';
  }
}

/// How cards leave the app: saved as a picture, or printed as a sheet. Kept
/// behind this small interface so the phone apps can use the share sheet
/// later without touching the screen, and tests can stand in for it.
abstract class CodeExporter {
  /// Saves the card as a PNG. Throws [AppFailure] when this device cannot.
  Future<void> saveImage(CodeCard card);

  /// Opens the print dialog for an A4 sheet of cards, three across.
  Future<void> printSheet(String title, List<CodeCard> cards);
}

class DeviceCodeExporter implements CodeExporter {
  const DeviceCodeExporter();

  Future<Uint8List> _png(CodeCard c) => renderTableCardPng(
    link: c.link,
    tableName: c.tableName,
    restaurant: c.restaurant,
    scanLine: c.scanLine,
  );

  @override
  Future<void> saveImage(CodeCard card) async {
    if (!canDownloadFiles) {
      throw const AppFailure(
        'Saving the picture works in the browser for now. On a phone, use '
        'Print all, or take a screenshot of the code.',
        kind: FailureKind.notReady,
        code: 'table_save_browser_only',
      );
    }
    final ok = await downloadBytes(
      await _png(card),
      card.fileName,
      'image/png',
    );
    if (!ok) {
      throw const AppFailure(
        'The picture could not be saved. Try again.',
        code: 'table_picture_not_saved',
      );
    }
  }

  @override
  Future<void> printSheet(String title, List<CodeCard> cards) async {
    final sheet = <SheetCard>[];
    for (final c in cards) {
      sheet.add(
        SheetCard(
          link: c.link,
          label: await renderTableLabelPng(
            tableName: c.tableName,
            restaurant: c.restaurant,
            scanLine: c.scanLine,
          ),
        ),
      );
    }
    final pdf = await buildTableSheetPdf(title: title, cards: sheet);
    final done = await Printing.layoutPdf(
      onLayout: (format) async => pdf,
      name: title,
    );
    if (!done) {
      throw const AppFailure(
        'The sheet was not printed. Check the printer and try again.',
        code: 'table_sheet_not_printed',
      );
    }
  }
}
