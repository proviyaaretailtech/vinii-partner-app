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

  String get initials {
    final parts = displayName
        .split(RegExp(r'[\s._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
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
}

const _leads = {
  'org_owner',
  'org_admin',
  'manager',
  'location_manager',
  'operations_manager',
};
const _floor = {..._leads, 'biller', 'captain', 'staff_user'};

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
};
