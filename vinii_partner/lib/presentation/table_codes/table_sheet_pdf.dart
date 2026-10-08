import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One card on the printed sheet: the address its code holds, and the
/// picture of the words that go under it (see `renderTableLabelPng`).
class SheetCard {
  const SheetCard({required this.link, required this.label});

  final String link;
  final Uint8List label;
}

/// An A4 sheet of table cards, [columns] across, ready to print and cut.
///
/// The code is drawn as vector squares (error correction level M, with a white
/// margin all round), so it stays sharp at any print size and the sheet stays
/// small and quick to build. Cards are outlined with a dashed line to cut on.
Future<Uint8List> buildTableSheetPdf({
  required String title,
  required List<SheetCard> cards,
  int columns = 3,
}) async {
  const margin = 24.0;
  // i18n-ignore: brand name in the PDF's metadata
  final doc = pw.Document(title: title, creator: 'VINII Partner');
  final cellWidth = (PdfPageFormat.a4.width - margin * 2) / columns;
  const cellHeight = 250.0;
  // What is left of a cell under the code: the cell, less its padding (14 + 8),
  // the code with its white margin (138 + 12) and the gap below the code (6).
  const labelHeight = cellHeight - 14 - 8 - 150 - 6;
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(margin),
      build: (context) => [
        pw.Wrap(
          children: [
            for (final c in cards)
              pw.Container(
                width: cellWidth,
                height: cellHeight,
                padding: const pw.EdgeInsets.fromLTRB(12, 14, 12, 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey500,
                    width: 0.6,
                    style: pw.BorderStyle.dashed,
                  ),
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: [
                    pw.Container(
                      color: PdfColors.white,
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(
                          errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                        ),
                        data: c.link,
                        width: 138,
                        height: 138,
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    // The words are a picture drawn by Flutter (the pdf
                    // package cannot shape Devanagari). It is scaled to fit
                    // the room left under the code, so a taller Hindi label
                    // shrinks a little instead of running out of the cell.
                    pw.Image(
                      pw.MemoryImage(c.label),
                      width: cellWidth - 24,
                      height: labelHeight,
                      fit: pw.BoxFit.contain,
                      alignment: pw.Alignment.topCenter,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}
