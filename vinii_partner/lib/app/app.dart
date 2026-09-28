import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../presentation/theme/staff_theme.dart';
import 'app_scope.dart';
import 'router.dart';

class ViniiPartnerApp extends StatefulWidget {
  const ViniiPartnerApp({super.key, required this.services});

  final AppServices services;

  @override
  State<ViniiPartnerApp> createState() => _ViniiPartnerAppState();
}

class _ViniiPartnerAppState extends State<ViniiPartnerApp> {
  late final GoRouter _router = buildRouter(widget.services);

  @override
  void initState() {
    super.initState();
    widget.services.session.boot();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return AppScope(
      services: s,
      child: ListenableBuilder(
        listenable: Listenable.merge([s.session, s.themeMode]),
        builder: (context, _) {
          // The organization's brand colour tints the staff app ("Chameleon",
          // OS migration 0009): every member sees their restaurant's colour.
          final accent = s.session.membership?.organization.accent;
          return MaterialApp.router(
            title: 'VINII Partner',
            debugShowCheckedModeBanner: false,
            theme: staffTheme(brightness: Brightness.light, accent: accent),
            darkTheme: staffTheme(brightness: Brightness.dark, accent: accent),
            themeMode: s.themeMode.value,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
