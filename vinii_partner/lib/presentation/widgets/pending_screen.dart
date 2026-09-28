import 'package:flutter/material.dart';

import 'state_views.dart';

/// Placeholder while a feature screen is being built. Remove when every
/// route has its real screen.
class PendingScreen extends StatelessWidget {
  const PendingScreen(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: const EmptyView(
      icon: Icons.construction_rounded,
      title: 'Being built',
      message: 'This screen is next.',
    ),
  );
}
