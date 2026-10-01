import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small per-device settings. Nothing here is a secret: the Supabase session
/// is kept by supabase_flutter itself.
class LocalPrefs {
  LocalPrefs(this._prefs);

  static Future<LocalPrefs> open() async =>
      LocalPrefs(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  bool get introSeen => _prefs.getBool('intro_seen') ?? false;
  Future<void> setIntroSeen() => _prefs.setBool('intro_seen', true);

  /// The organization this person last worked in, so a two-restaurant
  /// manager is not asked every morning.
  String? lastOrganization(String userId) =>
      _prefs.getString('last_org:$userId');
  Future<void> setLastOrganization(String userId, String orgId) =>
      _prefs.setString('last_org:$userId', orgId);
  Future<void> clearLastOrganization(String userId) =>
      _prefs.remove('last_org:$userId');

  ThemeMode get themeMode =>
      ThemeMode.values
          .where((m) => m.name == _prefs.getString('theme_mode'))
          .firstOrNull ??
      ThemeMode.system;
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString('theme_mode', mode.name);

  bool get ringEnabled => _prefs.getBool('ring_enabled') ?? true;
  Future<void> setRingEnabled(bool on) => _prefs.setBool('ring_enabled', on);

  /// Idempotency keys waiting for a server answer (contract R3), e.g.
  /// `order:<orgId>` or `payment:<orderId>`. Kept across restarts so a retry
  /// after the app was closed reuses the same key and cannot duplicate.
  String? pendingKey(String scope) => _prefs.getString('pending_key:$scope');
  Future<void> setPendingKey(String scope, String key) =>
      _prefs.setString('pending_key:$scope', key);
  Future<void> clearPendingKey(String scope) =>
      _prefs.remove('pending_key:$scope');

  /// The last service charge percentage above zero that this organization
  /// had, so switching the service charge back ON restores it instead of
  /// asking for the number again.
  double? lastServiceCharge(String orgId) =>
      _prefs.getDouble('last_service_charge:$orgId');
  Future<void> setLastServiceCharge(String orgId, double percent) =>
      _prefs.setDouble('last_service_charge:$orgId', percent);

  /// What the cashier chose when the final-order prompt offered to remove the
  /// service charge from this order: `keep` or `remove`. Remembered so the
  /// prompt shows once per order, even after the app restarts.
  String? serviceChargeChoice(String orderId) =>
      _prefs.getString('service_charge_choice:$orderId');
  Future<void> setServiceChargeChoice(String orderId, String choice) =>
      _prefs.setString('service_charge_choice:$orderId', choice);

  /// Storefront drafts are kept per organization on this phone until
  /// published (see StorefrontRepository implementations).
  Map<String, dynamic>? storefrontDraft(String orgId) {
    final raw = _prefs.getString('storefront_draft:$orgId');
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> setStorefrontDraft(String orgId, Map<String, dynamic>? json) =>
      json == null
      ? _prefs.remove('storefront_draft:$orgId')
      : _prefs.setString('storefront_draft:$orgId', jsonEncode(json));
}
