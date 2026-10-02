# 09 — Hardware

**Scope.** `vinii_partner/` at `da0a823`. Evidence labels are as in `01_DATABASE.md`.

**Dependencies** (`vinii_partner/pubspec.yaml`):
- `supabase_flutter`, `go_router`, `shared_preferences`, `intl`, `uuid`, `image_picker`, `audioplayers`, `qr_flutter`, `google_fonts`, `http`, `pdf`, `printing`, `web`.
- There is **no** Bluetooth, USB, serial, ESC/POS, NFC, barcode or scanner, payment-terminal or cash-drawer package.
- A search of `lib/` for `bluetooth`, `printer`, `esc_pos`, `serial`, `nfc`, `scanner`, `barcode` and `cash drawer` found no integration code.

| Device | Status | Evidence |
| --- | --- | --- |
| Thermal receipt printer | **Not integrated** | — |
| KOT printer | **Not integrated.** No KOT print or reprint | — |
| Barcode scanner | **Not integrated** | — |
| Cash drawer | **Not integrated** | — |
| Card or payment terminal | **Not integrated** | — |
| Bluetooth | **Not used** | — |
| Network printer | **Not integrated** | — |
| **System print dialog (PDF)** | **Used only for table QR codes.** `Printing.layoutPdf` prints an A4 sheet of table QR cards; a single card can be downloaded as a picture on web | `presentation/table_codes/code_exporter.dart:3,90`, `table_sheet_pdf.dart` |
| **Speaker** | Plays the new-order ring (`assets/sounds/new_order.wav`) with `audioplayers` | `application/ring_player.dart:16-60` |
| **Vibration** | `HapticFeedback.heavyImpact()` on a periodic `Timer` while ringing; Settings says vibration always stays on | `ring_player.dart:25-27`, `presentation/settings/settings_screen.dart:310` |
| **Camera / photo library** | `image_picker` for menu item photos, uploaded to `item-images` | `presentation/menu/item_editor_screen.dart:329`, `live_menu.dart:192-226` |
| **Screen** | Guest mode turns the staff phone into a guest ordering screen | 02 §B |
