import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/guest_gateway.dart';
import '../../application/guest_session.dart';
import '../../domain/menu.dart';
import '../../domain/pos_order.dart';
import '../../domain/storefront.dart';
import '../theme/guest_theme.dart';
import '../widgets/dish_art.dart';
import 'guest_welcome.dart';
import 'guest_widgets.dart';
import 'look/look.dart';

/// The guest storefront runtime: the whole swipe-to-order experience from
/// the two reference boards, rendered from a [StorefrontDefinition] and the
/// organization's real [MenuSnapshot].
///
/// Self-contained (its own theme and navigator), so it runs full screen when
/// a staff phone is handed to a table, inside Studio's phone-frame preview,
/// and later as the public website. It reaches the outside world only
/// through [gateway].
class GuestApp extends StatefulWidget {
  const GuestApp({
    super.key,
    required this.definition,
    required this.menu,
    required this.gateway,
    this.table,
    this.onExit,
    this.mediaBaseUrl = '',
  });

  final StorefrontDefinition definition;
  final MenuSnapshot menu;
  final GuestOrderGateway gateway;

  /// The table this phone was handed to, if any. Dine-in skips the table
  /// question when set.
  final DiningTable? table;

  /// Leaves the guest experience (staff only). Null inside Studio's preview.
  final VoidCallback? onExit;

  /// Where pictures uploaded in the CMS are served (`AppConfig.mediaBaseUrl`).
  final String mediaBaseUrl;

  @override
  State<GuestApp> createState() => _GuestAppState();
}

class _GuestAppState extends State<GuestApp> {
  /// Replaced with the session, so a new visit starts on a fresh stack.
  var _nav = GlobalKey<NavigatorState>();

  /// Lets a dish picture travel between the deck and its page. One per
  /// Navigator, replaced with it.
  var _hero = HeroController();
  late GuestSession _session;
  late GuestPalette _palette;
  late ThemeData _theme;
  bool _nestedCanPop = false;
  late final _observer = _NavObserver(_navChanged);

  @override
  void initState() {
    super.initState();
    _session = _newSession();
    _restyle();
  }

  GuestSession _newSession() {
    final s = GuestSession(
      definition: widget.definition,
      menu: widget.menu,
      gateway: widget.gateway,
      table: widget.table,
    );
    unawaited(s.loadCharges());
    return s;
  }

  void _restyle() {
    _palette = GuestPalette.from(widget.definition);
    _theme = _palette.toTheme();
  }

  @override
  void didUpdateWidget(GuestApp old) {
    super.didUpdateWidget(old);
    if (old.gateway != widget.gateway || old.table?.id != widget.table?.id) {
      // A different outside world (or table) is a different visit.
      final previous = _session;
      _session = _newSession();
      _nav = GlobalKey<NavigatorState>();
      _hero = HeroController();
      _nestedCanPop = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    } else if (old.definition != widget.definition || old.menu != widget.menu) {
      // Studio's live preview: keep the party where it is.
      _session.reconfigure(definition: widget.definition, menu: widget.menu);
    }
    if (old.definition != widget.definition) _restyle();
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _navChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final can = _nav.currentState?.canPop() ?? false;
      if (mounted && can != _nestedCanPop) {
        setState(() => _nestedCanPop = can);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: GuestScope(
        session: _session,
        onExit: widget.onExit,
        mediaBaseUrl: widget.mediaBaseUrl,
        child: ScaffoldMessenger(
          // Handed to guests, "back" only ever moves within the runtime;
          // in a preview it may leave once the runtime is at its start.
          child: PopScope(
            canPop: widget.onExit == null && !_nestedCanPop,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _nav.currentState?.maybePop();
            },
            child: ColoredBox(
              color: _palette.background,
              child: ClipRect(
                child: Navigator(
                  key: _nav,
                  observers: [_observer, _hero],
                  onGenerateRoute: (settings) =>
                      guestRoute<void>(const _GuestRoot()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavObserver extends NavigatorObserver {
  _NavObserver(this.onChange);
  final VoidCallback onChange;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChange();
}

/// The first screen: the welcome, or — when nothing on the menu can be sold
/// yet — an honest "being prepared" page instead of an empty storefront.
class _GuestRoot extends StatelessWidget {
  const _GuestRoot();

  @override
  Widget build(BuildContext context) {
    final s = GuestScope.of(context);
    return s.catalog.isEmpty
        ? const _MenuPreparing()
        : const GuestWelcomeScreen();
  }
}

class _MenuPreparing extends StatelessWidget {
  const _MenuPreparing();

  @override
  Widget build(BuildContext context) {
    final p = GuestPalette.of(context);
    final brand = GuestScope.of(context).definition.brand;
    return GuestPage(
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerRight,
            child: GuestExitButton(),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const GuestLogo(size: 72),
                    const SizedBox(height: 20),
                    Text(
                      brand.displayName,
                      textAlign: TextAlign.center,
                      style: p.display(30),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 120,
                      child: DishArt(
                        name: 'tea',
                        family: DishFamily.cup,
                        light: p.keyLight,
                        onDark: p.isDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      GuestCopy.of(context)('menu.empty'),
                      textAlign: TextAlign.center,
                      style: p.display(22, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check back in a little while, or ask a member '
                      'of our staff.',
                      textAlign: TextAlign.center,
                      style: p.body(15, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
