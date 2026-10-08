import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'state_views.dart';

/// Placeholder while a feature screen is being built. Remove when every
/// route has its real screen.
class PendingScreen extends StatelessWidget {
  const PendingScreen(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: EmptyView(
      icon: Icons.construction_rounded,
      title: context.l10n.uiBeingBuilt,
      message: context.l10n.uiBeingBuiltHint,
    ),
  );
}
