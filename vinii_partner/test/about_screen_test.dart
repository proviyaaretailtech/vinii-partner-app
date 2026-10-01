import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/presentation/settings/about_screen.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  testWidgets(
    'About says why these values are shown and that nothing is asked of you',
    (tester) async {
      final services = await testServices(FakeBackend());
      await tester.pumpWidget(wrapScreen(services, const AboutScreen()));
      await tester.pump();

      expect(
        find.text(
          'Support may ask you to read these out. You do not need to change '
          'or do anything with them.',
        ),
        findsOneWidget,
      );
      expect(find.text('App version'), findsOneWidget);
      expect(find.text('Environment'), findsOneWidget);
    },
  );
}
