import 'staff.dart';

/// The bottom-navigation destinations this runtime knows how to show.
enum AppTab {
  orders('Orders', 'orders'),
  sell('Sell', 'pos'),
  menu('Menu', 'menu'),
  storefront('Storefront', 'menu'),
  more('More', 'dashboard');

  const AppTab(this.label, this.moduleKey);
  final String label;

  /// The OS module (`modules.key`) that must be on for this tab to appear.
  /// Storefront is the menu module's "publishing" submodule in the OS
  /// registry, so it follows the menu module.
  final String moduleKey;

  Capability? get capability => switch (this) {
    AppTab.orders => Capability.viewOrders,
    AppTab.sell => Capability.sell,
    AppTab.menu => Capability.viewMenu,
    AppTab.storefront => Capability.viewStorefront,
    AppTab.more => null,
  };
}

/// What this person sees in this organization, resolved once at boot and on
/// every organization switch. This is the "application definition": the same
/// app becomes a different app per organization and role through data, with
/// no organization names anywhere in the code.
///
/// Resolution follows the founder documents' chain (viyaa routes §35–36):
/// module enabled for the organization (`org_modules`) → visible to the role
/// (`role_module_access`) → allowed for the role (capabilities) → shown.
class AppDefinition {
  const AppDefinition({
    required this.tabs,
    required this.enabledModules,
    required this.minAppVersion,
    required this.configVersion,
    required this.source,
  });

  final List<AppTab> tabs;
  final Set<String> enabledModules;

  /// From `organizations.settings.app.min_app_version`. Older builds stop at
  /// the "Update required" screen instead of misbehaving.
  final String minAppVersion;

  /// Shown in Settings → About so support can see which configuration a
  /// phone is running.
  final String configVersion;

  /// Where the module list came from — `org_modules`, or `defaults` when the
  /// organization has no module rows the app can read.
  final String source;

  AppTab get home => tabs.first;
}

/// Pure function so it can be unit-tested without a backend.
///
/// [orgModules] is `module_key → enabled`, or null when unknown (table not
/// readable); unknown means "everything the role may use".
/// [roleVisibility] is `module_key → visible` for this role, org overrides
/// already applied; missing keys mean visible.
AppDefinition resolveAppDefinition({
  required Membership membership,
  Map<String, bool>? orgModules,
  Map<String, bool> roleVisibility = const {},
}) {
  final appSettings = membership.organization.settings['app'];
  final app = appSettings is Map ? appSettings : const {};

  bool moduleOn(String key) {
    if (orgModules == null) return true;
    // Core modules (dashboard, orders, pos, menu) are on unless a row says off.
    return orgModules[key] ??
        const {'dashboard', 'orders', 'pos', 'menu'}.contains(key);
  }

  final order = <AppTab>[
    for (final key in (app['tabs'] is List ? app['tabs'] as List : const []))
      ...AppTab.values.where((t) => t.name == key),
    ...AppTab.values,
  ];

  final tabs = <AppTab>[];
  for (final tab in order) {
    if (tabs.contains(tab)) continue;
    if (tab != AppTab.more) {
      if (!moduleOn(tab.moduleKey)) continue;
      if (roleVisibility[tab.moduleKey] == false) continue;
      final cap = tab.capability;
      if (cap != null && !membership.can(cap)) continue;
    }
    tabs.add(tab);
  }
  // "More" (profile, organization, sign out) is always last and always there.
  tabs
    ..remove(AppTab.more)
    ..add(AppTab.more);

  return AppDefinition(
    tabs: tabs,
    enabledModules: {
      if (orgModules == null) ...AppTab.values.map((t) => t.moduleKey),
      if (orgModules != null)
        ...orgModules.entries.where((e) => e.value).map((e) => e.key),
    },
    minAppVersion: (app['min_app_version'] as String?) ?? '0.0.0',
    configVersion: '${app['config_version'] ?? 'default'}',
    source: orgModules == null ? 'defaults' : 'org_modules',
  );
}

/// `1.2.10` > `1.2.9`. Non-numeric parts count as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split(RegExp(r'[.+-]'))
      .take(3)
      .map((p) => int.tryParse(p) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0, y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
