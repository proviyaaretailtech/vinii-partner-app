import 'organization.dart';

/// The signed-in person. One login serves every Proviyaa app (One Local,
/// the POS, this app), so this is deliberately thin.
class StaffUser {
  const StaffUser({required this.id, required this.email, this.fullName});

  final String id;
  final String email;
  final String? fullName;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email.split('@').first;
  }

  String get initials => initialsOf(displayName);
}

/// "Priya Deshmukh" → "PD", "priya.d@example.com" → "PD"; one word gives one
/// letter. Shared by the signed-in person and the team list.
String initialsOf(String name) {
  final parts = name
      .split(RegExp(r'[\s._-]+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// One row of `org_users`: this person, in this organization, in this role.
/// A person may belong to several organizations (a manager running two
/// outlets, a consultant) and picks which one the app is working in.
class Membership {
  const Membership({
    required this.organization,
    required this.roleSlug,
    required this.roleName,
    this.active = true,
  });

  final Organization organization;

  /// `roles.slug`: org_owner, org_admin, manager, biller, captain, kitchen…
  final String roleSlug;

  /// `roles.name` for display: "Manager", "KOT / Kitchen".
  final String roleName;

  /// `org_users.status == 'active'`. Suspended memberships are listed but
  /// cannot be opened.
  final bool active;

  bool can(Capability c) =>
      active && (capabilityRoles[c]?.contains(roleSlug) ?? false);
}

/// What a person may do in this app. Screens ask `session.can(...)`, never
/// "is this the manager of X" — roles map to capabilities in one table.
enum Capability {
  viewOrders,
  acceptOrders,
  markReady,
  dispatchOrders,
  toggleOutlet,
  sendTestOrder,
  sell,
  takePayment,
  handToGuest,
  viewMenu,
  editMenu,
  toggleAvailability,
  viewStorefront,
  editStorefront,
  publishStorefront,

  /// See the GST, service charge and printed-bill settings.
  viewBillSettings,

  /// Change them. The database lets any member write today (gap G2), so the
  /// app limits this to the people who own the restaurant's money.
  editBillSettings,

  /// Take the service charge off one bill at the final order.
  waiveServiceCharge,

  /// Switch Swiggy, Zomato and the other sales channels ON or OFF.
  toggleChannels,

  /// See who is on the team and what each role can do.
  viewTeam,

  /// Change a role or suspend a person. The database only lets an
  /// organization admin do this (`is_org_admin`), so this matches it.
  manageTeam,

  /// See each table's QR code.
  viewTableCodes,

  /// Issue or re-issue a table's QR code.
  issueTableCodes,
}

const _leads = {
  'org_owner',
  'org_admin',
  'manager',
  'location_manager',
  'operations_manager',
};
const _floor = {..._leads, 'biller', 'captain', 'staff_user'};

/// Every restaurant role in the `roles` table (OS migrations 0004 and 0019).
/// Anyone on the team may look at the team list, as the database allows.
const _everyone = {
  ..._floor,
  'kitchen',
  'viewer',
  'business_manager',
  'finance_manager',
  'accountant',
  'hr_manager',
  'marketing_manager',
  'inventory_manager',
  'procurement_manager',
  'support_user',
  'analyst',
};

/// Mirrors the partner server's role table (One Local `server/partner.ts`)
/// for the order actions, and the POS PRD's role list for the rest, so the
/// app never offers a button the server will refuse. This only decides which
/// buttons show; the server is the authority (contract R8).
const Map<Capability, Set<String>> capabilityRoles = {
  Capability.viewOrders: {..._floor, 'kitchen', 'viewer', 'business_manager'},
  Capability.acceptOrders: {..._leads, 'biller'},
  Capability.markReady: {..._leads, 'biller', 'kitchen'},
  Capability.dispatchOrders: {..._leads, 'biller'},
  Capability.toggleOutlet: _leads,
  Capability.sendTestOrder: {..._leads, 'biller'},
  Capability.sell: _floor,
  Capability.takePayment: {..._leads, 'biller'},
  Capability.handToGuest: _floor,
  Capability.viewMenu: {
    ..._floor,
    'kitchen',
    'inventory_manager',
    'marketing_manager',
  },
  // Contract R4: until the database checks roles on menu writes (gap G2),
  // live menu editing is limited to these three roles.
  Capability.editMenu: {'org_owner', 'org_admin', 'manager'},
  Capability.toggleAvailability: {'org_owner', 'org_admin', 'manager'},
  Capability.viewStorefront: {
    ..._leads,
    'marketing_manager',
    'business_manager',
  },
  Capability.editStorefront: {..._leads, 'marketing_manager'},
  // Publishing changes what every guest sees: owners and admins only, as the
  // proposed vinii_storefronts policies allow (contract §4.4).
  Capability.publishStorefront: {'org_owner', 'org_admin'},
  Capability.viewBillSettings: {..._leads, 'biller'},
  Capability.editBillSettings: {'org_owner', 'org_admin'},
  Capability.waiveServiceCharge: {'org_owner', 'org_admin', 'manager'},
  Capability.toggleChannels: {'org_owner', 'org_admin', 'manager'},
  Capability.viewTeam: _everyone,
  // `org_users` writes pass only `is_org_admin` (slug = 'org_admin'), not
  // org_owner, so the owner sees the team but cannot change it here.
  Capability.manageTeam: {'org_admin'},
  Capability.viewTableCodes: _floor,
  Capability.issueTableCodes: {'org_admin', 'manager'},
};

/// One row of the `roles` table.
class StaffRole {
  const StaffRole({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
  });

  final String id;

  /// `org_admin`, `manager`, `biller`…
  final String slug;

  /// "Manager", "KOT / Kitchen".
  final String name;
  final String? description;
}

/// One row of `org_users`: a person on this restaurant's team.
class TeamMember {
  const TeamMember({
    required this.id,
    required this.userId,
    required this.email,
    required this.role,
    this.fullName,
    this.active = true,
  });

  /// `org_users.id`.
  final String id;

  /// `org_users.user_id`, to recognise the signed-in person in the list.
  final String userId;
  final String email;
  final String? fullName;
  final StaffRole role;

  /// `org_users.status == 'active'` (otherwise 'suspended').
  final bool active;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email;
  }

  /// "AV" for Asha Verma; the first letter of the part before the @ when
  /// there is no name on file.
  String get initials => initialsOf(
    fullName?.trim().isNotEmpty ?? false
        ? fullName!.trim()
        : email.split('@').first,
  );

  /// The role that the database lets manage the team.
  bool get isAdmin => role.slug == 'org_admin';

  TeamMember copyWith({StaffRole? role, bool? active}) => TeamMember(
    id: id,
    userId: userId,
    email: email,
    fullName: fullName,
    role: role ?? this.role,
    active: active ?? this.active,
  );
}

/// One thing a role can do in this app, as a code with no words in it. The
/// Team screen turns each into a phrase in the reader's language
/// (lib/presentation/team/role_summary_l10n.dart); [roleSummary] keeps the
/// English sentence for tests and logs.
enum RoleAbility {
  manageTeam,
  changeBillSettings,
  publishStorefront,
  editStorefront,
  editMenu,
  switchDishes,
  changeStoreStatus,
  waiveServiceCharge,
  takePayments,
  takeTableOrders,
  acceptDeliveryOrders,
  markFoodReady,
  seeDeliveryOrders,
  seeMenu,
  seeBillSettings,
}

/// Strongest ability first. Each row: the capability that earns it, the
/// ability, and the weaker capabilities it makes redundant ("edit the menu"
/// covers "see the menu").
const _abilityTable = <(Capability, RoleAbility, List<Capability>)>[
  (Capability.manageTeam, RoleAbility.manageTeam, [Capability.viewTeam]),
  (
    Capability.editBillSettings,
    RoleAbility.changeBillSettings,
    [Capability.viewBillSettings],
  ),
  (
    Capability.publishStorefront,
    RoleAbility.publishStorefront,
    [Capability.editStorefront, Capability.viewStorefront],
  ),
  (
    Capability.editStorefront,
    RoleAbility.editStorefront,
    [Capability.viewStorefront],
  ),
  (
    Capability.editMenu,
    RoleAbility.editMenu,
    [Capability.toggleAvailability, Capability.viewMenu],
  ),
  (
    Capability.toggleAvailability,
    RoleAbility.switchDishes,
    [Capability.viewMenu],
  ),
  (Capability.toggleOutlet, RoleAbility.changeStoreStatus, []),
  (Capability.waiveServiceCharge, RoleAbility.waiveServiceCharge, []),
  (Capability.takePayment, RoleAbility.takePayments, []),
  (Capability.sell, RoleAbility.takeTableOrders, [Capability.handToGuest]),
  (
    Capability.acceptOrders,
    RoleAbility.acceptDeliveryOrders,
    [Capability.viewOrders],
  ),
  (Capability.markReady, RoleAbility.markFoodReady, []),
  (Capability.viewOrders, RoleAbility.seeDeliveryOrders, []),
  (Capability.viewMenu, RoleAbility.seeMenu, []),
  (Capability.viewBillSettings, RoleAbility.seeBillSettings, []),
];

/// What a role can do in this app, strongest first, built from the same
/// [capabilityRoles] table the screens ask, so the list can never drift from
/// what the buttons do. Strong abilities swallow the weaker ones they include
/// ("edit the menu" covers "see the menu"). Empty when the role has nothing in
/// this app.
List<RoleAbility> roleAbilities(String roleSlug) {
  bool has(Capability c) => capabilityRoles[c]?.contains(roleSlug) ?? false;

  final covered = <Capability>{};
  final said = <RoleAbility>[];
  for (final (cap, ability, includes) in _abilityTable) {
    if (!has(cap) || covered.contains(cap)) continue;
    said.add(ability);
    covered.addAll(includes);
  }
  return said;
}

/// The English sentence for [roleAbilities], for tests and logs only: a
/// person reads `roleSummaryText` (role_summary_l10n.dart) in their language.
String roleSummary(String roleSlug) {
  final said = roleAbilities(roleSlug);
  if (said.isEmpty) return 'Cannot use Orders, Sell or Menu in this app.'; // i18n-ignore: English for tests/logs

  const show = 3;
  final shown = [for (final a in said.take(show)) _englishPhrase(a)];
  final String list;
  if (said.length > show) {
    list =
        '${shown.join(', ')} and more'; // i18n-ignore: English for tests/logs
  } else if (shown.length == 1) {
    list = shown.single;
  } else {
    list =
        '${shown.sublist(0, shown.length - 1).join(', ')}'
        ' and ${shown.last}'; // i18n-ignore: English for tests/logs
  }
  return 'Can $list.'; // i18n-ignore: English for tests/logs
}

String _englishPhrase(RoleAbility a) => switch (a) {
  RoleAbility.manageTeam =>
    'manage the team', // i18n-ignore: English for tests/logs
  RoleAbility.changeBillSettings =>
    'change the bill and GST settings', // i18n-ignore: English for tests/logs
  RoleAbility.publishStorefront =>
    'publish the guest storefront', // i18n-ignore: English for tests/logs
  RoleAbility.editStorefront =>
    'edit the guest storefront', // i18n-ignore: English for tests/logs
  RoleAbility.editMenu =>
    'edit the menu', // i18n-ignore: English for tests/logs
  RoleAbility.switchDishes =>
    'switch dishes on and off', // i18n-ignore: English for tests/logs
  RoleAbility.changeStoreStatus =>
    'change the store status', // i18n-ignore: English for tests/logs
  RoleAbility.waiveServiceCharge => 'remove the service charge from a bill', // i18n-ignore: English for tests/logs
  RoleAbility.takePayments =>
    'take payments', // i18n-ignore: English for tests/logs
  RoleAbility.takeTableOrders =>
    'take table orders', // i18n-ignore: English for tests/logs
  RoleAbility.acceptDeliveryOrders =>
    'accept delivery orders', // i18n-ignore: English for tests/logs
  RoleAbility.markFoodReady =>
    'mark food ready', // i18n-ignore: English for tests/logs
  RoleAbility.seeDeliveryOrders =>
    'see delivery orders', // i18n-ignore: English for tests/logs
  RoleAbility.seeMenu => 'see the menu', // i18n-ignore: English for tests/logs
  RoleAbility.seeBillSettings =>
    'see the bill settings', // i18n-ignore: English for tests/logs
};
