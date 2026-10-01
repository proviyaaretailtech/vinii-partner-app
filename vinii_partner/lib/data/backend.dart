import 'dart:typed_data';

import '../domain/app_definition.dart';
import '../domain/billing.dart';
import '../domain/delivery_order.dart';
import '../domain/menu.dart';
import '../domain/organization.dart';
import '../domain/pos_order.dart';
import '../domain/staff.dart';
import '../domain/storefront.dart';

/// Every data source the app uses, behind one seam. `LiveBackend` talks to
/// Supabase and the One Local partner API; tests substitute an empty fake.
/// Screens never know which one they have.
///
/// All repositories except [auth] and [workspace] act on the organization
/// most recently passed to [WorkspaceRepository.activate].
abstract class Backend {
  AuthGateway get auth;
  WorkspaceRepository get workspace;
  MenuRepository get menu;
  PosRepository get pos;
  DeliveryInbox get inbox;
  StorefrontRepository get storefront;
  BillSettingsRepository get billSettings;
  TeamRepository get team;
  TablesRepository get tableCodes;
  ChannelsRepository get channels;

  /// Called once at boot before anything else (Supabase init, etc.).
  Future<void> start();
}

abstract class AuthGateway {
  StaffUser? get currentUser;

  /// Emits when the session ends outside the app's control (expired, signed
  /// out on another device with "sign out everywhere").
  Stream<StaffUser?> get changes;

  /// Throws [AppFailure] with kind `auth` for a wrong email or password.
  Future<StaffUser> signIn({required String email, required String password});

  /// Sends Supabase's reset email. Succeeds even for unknown emails, so the
  /// screen cannot be used to discover who has an account.
  Future<void> sendPasswordReset(String email);

  /// [everywhere] ends every session of this account, not just this phone.
  Future<void> signOut({bool everywhere = false});
}

abstract class WorkspaceRepository {
  /// Every organization this person belongs to, suspended ones included.
  Future<List<Membership>> memberships(StaffUser user);

  /// Points every organization-scoped repository at [org].
  Future<void> activate(Organization org);

  /// Tabs, modules and version gate for this person in this organization.
  Future<AppDefinition> appDefinition(Membership membership);
}

abstract class MenuRepository {
  Future<MenuSnapshot> load();
  Future<MenuCategory> saveCategory(
    MenuCategory category, {
    required bool isNew,
  });

  /// Items in a deleted category are kept and become "Uncategorised".
  Future<void> deleteCategory(String categoryId);
  Future<void> reorderCategories(List<String> categoryIdsInOrder);
  Future<MenuItem> saveItem(MenuItem item, {required bool isNew});
  Future<void> setItemAvailable(String itemId, bool available);

  /// Uploads a photo and returns its public URL (`item-images` bucket).
  Future<String> uploadItemImage(
    String itemId,
    Uint8List bytes, {
    required String extension,
  });
}

/// POS orders. Reads are plain selects; every write goes through the
/// POS-owned front-door functions (contract R1): `pos_place_order`,
/// `pos_record_payment`, `pos_set_order_status`. Until those exist the
/// writes fail with [FailureKind.notReady] — never a direct table write.
abstract class PosRepository {
  Future<List<DiningTable>> tables();

  /// `org_bill_settings` for the preview bill (defaults when absent).
  Future<BillCharges> billCharges();

  /// One transaction on the server: priced from the menu, numbered, lines,
  /// kitchen ticket and "placed" event. The draft's idempotency key makes a
  /// retry return the first order.
  Future<PlacedOrder> placeOrder(PosOrderDraft draft);

  /// [idempotencyKey] is created when the cashier confirms the payment and
  /// reused on retry, so a payment is never recorded twice.
  /// [reference] is the UPI or card reference, when the cashier has one.
  Future<PlacedOrder> recordPayment(
    PlacedOrder order,
    PaymentMethod method,
    double amount, {
    required String idempotencyKey,
    String? reference,
  });

  /// Today's orders that are not paid or cancelled, newest first.
  Future<List<PlacedOrder>> openOrders();
  Future<PlacedOrder> refresh(String orderId);

  /// [reason] is required by the server when cancelling.
  Future<PlacedOrder> setStatus(
    PlacedOrder order,
    PosStatus status, {
    String? reason,
  });

  /// Takes the service charge off a saved, unpaid order, or puts it back
  /// (the final-order prompt). The server checks the role, recomputes the
  /// bill and records who did it and why; it answers with the order. Calls
  /// the proposed `pos_adjust_bill` (contract §4.5), so until that exists it
  /// fails with [FailureKind.notReady].
  Future<PlacedOrder> adjustBill(
    PlacedOrder order, {
    required bool waiveServiceCharge,
    String? reason,
  });
}

/// Marketplace delivery orders (One Local), per the partner API contract.
abstract class DeliveryInbox {
  /// False when this build cannot reach the partner API (live mode without
  /// PARTNER_API_BASE_URL); [unavailableReason] says why, in plain words.
  bool get available;
  String? get unavailableReason;

  Future<OutletStatus> outlet();
  Future<OutletStatus> setAccepting(bool accepting, {DateTime? backAt});
  Future<List<DeliveryOrder>> list(InboxTab tab);
  Future<DeliveryOrder> detail(String orderId);
  Future<DeliveryOrder> accept(DeliveryOrder order, {required int prepMinutes});
  Future<DeliveryOrder> reject(DeliveryOrder order, {required String reason});
  Future<DeliveryOrder> markReady(DeliveryOrder order);
  Future<DeliveryOrder> markOut(DeliveryOrder order);
  Future<DeliveryOrder> markDelivered(DeliveryOrder order);

  /// Creates a fake order for this restaurant only and returns its id.
  Future<String> sendTestOrder();
}

abstract class StorefrontRepository {
  Future<StorefrontState> load(Organization org);
  Future<void> saveDraft(Organization org, StorefrontDefinition draft);
  Future<void> discardDraft(Organization org);
  Future<StorefrontVersion> publish(
    Organization org,
    StorefrontDefinition definition, {
    required String publishedBy,
  });
}

/// `org_bill_settings`: the restaurant's GST, service charge, rounding and
/// what is printed at the top and bottom of a bill.
abstract class BillSettingsRepository {
  /// The organization's row, or [BillSettings.defaults] (with no `updatedAt`)
  /// when it has none yet.
  Future<BillSettings> load();

  /// Writes every field. [settings] carries the `updatedAt` it was loaded
  /// with: if someone saved since, this throws [FailureKind.conflict] and
  /// writes nothing. With no `updatedAt` it creates the row (an upsert on
  /// `organization_id`) and never replaces one that appeared meanwhile.
  Future<BillSettings> save(BillSettings settings);
}

/// The people on this restaurant's team (`org_users` with their `roles`).
/// Reads are open to every member; the database lets only an organization
/// admin change anything (`is_org_admin`).
abstract class TeamRepository {
  Future<List<TeamMember>> members();
  Future<List<StaffRole>> roles();
  Future<TeamMember> setRole(TeamMember member, StaffRole role);
  Future<TeamMember> setStatus(TeamMember member, {required bool active});
}

/// Tables and their guest QR codes (`dining_tables`, `dining_areas`).
abstract class TablesRepository {
  /// Every table, active or not, in floor order.
  Future<List<TableCode>> list();

  /// Issues a code for a table that has none, or replaces the one it has
  /// (the old sticker stops working). Calls the proposed
  /// `pos_issue_table_qr` (contract §4.5), so until that exists it fails
  /// with [FailureKind.notReady]. [replace] must be true to replace a code.
  Future<TableCode> issueCode(TableCode table, {bool replace = false});
}

/// Swiggy, Zomato and the other sales channels (`channel_integrations`).
abstract class ChannelsRepository {
  Future<List<SalesChannel>> list();
  Future<SalesChannel> setAccepting(SalesChannel channel, bool accepting);
}
