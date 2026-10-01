import 'dart:async';
import 'dart:typed_data';

import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/data/backend.dart';
import 'package:vinii_partner/domain/app_definition.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/organization.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/domain/storefront.dart';

/// Test-only stand-in for the live backend. It starts EMPTY: each test puts
/// in exactly the rows it needs. It is never part of the app.
class FakeBackend implements Backend {
  FakeBackend({
    this.user,
    this.memberships = const [],
    MenuSnapshot? menu,
    this.tables = const [],
    this.inboxAvailable = true,
  }) : menuSnapshot = menu ?? MenuSnapshot.empty;

  StaffUser? user;
  List<Membership> memberships;
  MenuSnapshot menuSnapshot;
  List<DiningTable> tables;
  bool inboxAvailable;

  /// Set to make the next matching call fail.
  AppFailure? failSignIn;
  AppFailure? failPlaceOrder;
  AppFailure? failStorefrontPublish;
  AppFailure? failBillSettingsSave;
  AppFailure? failAdjustBill;
  AppFailure? failIssueCode;
  AppFailure? failTeamChange;
  AppFailure? failChannelChange;
  AppFailure? failOutletChange;

  /// Fails the Nth (1-based) payment call, to test a split payment whose
  /// second part does not go through.
  final failPaymentOnCall = <int, AppFailure>{};
  var _paymentCalls = 0;

  final deliveries = <DeliveryOrder>[];
  OutletStatus outletStatus = const OutletStatus(accepting: true);
  final placed = <PosOrderDraft>[];
  final payments =
      <({String orderId, PaymentMethod method, double amount, String key})>[];

  /// The organization's rates, as `pos.billCharges()` answers.
  BillCharges billCharges = BillCharges.defaults;

  /// Today's unpaid orders, as `pos.openOrders()` answers.
  List<PlacedOrder> openOrderRows = [];

  /// Bill changes asked for on saved orders.
  final adjustments =
      <({String orderId, bool waive, String? reason, String version})>[];

  /// `org_bill_settings` as the fake database holds it, with the version
  /// (`updatedAt`) a save must present. Starts as "no row yet".
  BillSettings billSettingsRow = BillSettings.defaults;
  final billSettingsSaves = <BillSettings>[];
  var _billVersion = 0;

  /// Bumps the stored version, as if someone else saved in the meantime.
  void saveBillSettingsElsewhere(BillSettings next) {
    billSettingsRow = next.copyWith(updatedAt: 'v${++_billVersion}');
  }

  /// The team and the roles table.
  List<TeamMember> teamMembers = [];
  List<StaffRole> staffRoles = [];
  final teamChanges = <String>[];

  /// Tables and their QR codes; [issuedCodes] counts codes handed out.
  List<TableCode> tableCodeRows = [];
  var issuedCodes = 0;

  /// Sales channels (`channel_integrations`).
  List<SalesChannel> channelRows = [];

  StorefrontState storefrontState = const StorefrontState();
  Organization? active;
  final signOutCalls = <bool>[];

  @override
  late final AuthGateway auth = _Auth(this);
  @override
  late final WorkspaceRepository workspace = _Workspace(this);
  @override
  late final MenuRepository menu = _Menu(this);
  @override
  late final PosRepository pos = _Pos(this);
  @override
  late final DeliveryInbox inbox = _Inbox(this);
  @override
  late final StorefrontRepository storefront = _Storefront(this);
  @override
  late final BillSettingsRepository billSettings = _BillSettings(this);
  @override
  late final TeamRepository team = _Team(this);
  @override
  late final TablesRepository tableCodes = _Tables(this);
  @override
  late final ChannelsRepository channels = _Channels(this);

  @override
  Future<void> start() async {}
}

class _Auth implements AuthGateway {
  _Auth(this.b);
  final FakeBackend b;
  final _changes = StreamController<StaffUser?>.broadcast();

  @override
  StaffUser? get currentUser => b.user;

  @override
  Stream<StaffUser?> get changes => _changes.stream;

  @override
  Future<StaffUser> signIn({
    required String email,
    required String password,
  }) async {
    if (b.failSignIn != null) throw b.failSignIn!;
    b.user = StaffUser(id: 'u-1', email: email);
    return b.user!;
  }

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut({bool everywhere = false}) async {
    b.signOutCalls.add(everywhere);
    b.user = null;
  }
}

class _Workspace implements WorkspaceRepository {
  _Workspace(this.b);
  final FakeBackend b;

  @override
  Future<List<Membership>> memberships(StaffUser user) async => b.memberships;

  @override
  Future<void> activate(Organization org) async => b.active = org;

  @override
  Future<AppDefinition> appDefinition(Membership membership) async =>
      resolveAppDefinition(membership: membership, orgModules: const {});
}

class _Menu implements MenuRepository {
  _Menu(this.b);
  final FakeBackend b;

  @override
  Future<MenuSnapshot> load() async => b.menuSnapshot;

  @override
  Future<MenuCategory> saveCategory(
    MenuCategory category, {
    required bool isNew,
  }) async {
    final saved = isNew
        ? MenuCategory(
            id: 'c-${b.menuSnapshot.categories.length + 1}',
            name: category.name,
          )
        : category;
    b.menuSnapshot = MenuSnapshot(
      categories: [
        ...b.menuSnapshot.categories.where((c) => c.id != saved.id),
        saved,
      ],
      items: b.menuSnapshot.items,
    );
    return saved;
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    b.menuSnapshot = MenuSnapshot(
      categories: b.menuSnapshot.categories
          .where((c) => c.id != categoryId)
          .toList(),
      items: [
        for (final i in b.menuSnapshot.items)
          i.categoryId == categoryId ? i.copyWith(clearCategory: true) : i,
      ],
    );
  }

  @override
  Future<void> reorderCategories(List<String> categoryIdsInOrder) async {}

  @override
  Future<MenuItem> saveItem(MenuItem item, {required bool isNew}) async {
    final saved = isNew
        ? MenuItem(
            id: 'i-${b.menuSnapshot.items.length + 1}',
            name: item.name,
            price: item.price,
            categoryId: item.categoryId,
          )
        : item;
    b.menuSnapshot = MenuSnapshot(
      categories: b.menuSnapshot.categories,
      items: [...b.menuSnapshot.items.where((i) => i.id != saved.id), saved],
    );
    return saved;
  }

  @override
  Future<void> setItemAvailable(String itemId, bool available) async {
    b.menuSnapshot = MenuSnapshot(
      categories: b.menuSnapshot.categories,
      items: [
        for (final i in b.menuSnapshot.items)
          i.id == itemId ? i.copyWith(isAvailable: available) : i,
      ],
    );
  }

  @override
  Future<String> uploadItemImage(
    String itemId,
    Uint8List bytes, {
    required String extension,
  }) async => 'https://example.test/$itemId.$extension';
}

class _Pos implements PosRepository {
  _Pos(this.b);
  final FakeBackend b;

  @override
  Future<List<DiningTable>> tables() async => b.tables;

  @override
  Future<BillCharges> billCharges() async => b.billCharges;

  @override
  Future<PlacedOrder> placeOrder(PosOrderDraft draft) async {
    if (b.failPlaceOrder != null) throw b.failPlaceOrder!;
    b.placed.add(draft);
    final order = PlacedOrder(
      id: 'o-${b.placed.length}',
      version: 'v1',
      displayNo: 'ORD-${b.placed.length}',
      status: PosStatus.sentToKitchen,
      serviceType: draft.serviceType,
      createdAt: DateTime(2026, 9, 28, 12),
      lines: draft.lines,
      bill: draft.bill,
      table: draft.table,
      placedBy: draft.placedBy,
    );
    b.openOrderRows = [order, ...b.openOrderRows];
    return order;
  }

  @override
  Future<PlacedOrder> recordPayment(
    PlacedOrder order,
    PaymentMethod method,
    double amount, {
    required String idempotencyKey,
    String? reference,
  }) async {
    final call = ++b._paymentCalls;
    final failure = b.failPaymentOnCall[call];
    if (failure != null) throw failure;
    b.payments.add((
      orderId: order.id,
      method: method,
      amount: amount,
      key: idempotencyKey,
    ));
    final paid = order.paidAmount + amount;
    final updated = order.copyWith(
      paidAmount: paid,
      status: paid >= order.bill.payable ? PosStatus.paid : order.status,
    );
    b.openOrderRows = [
      for (final o in b.openOrderRows)
        if (o.id != order.id) o else if (updated.status.isOpen) updated,
    ];
    return updated;
  }

  @override
  Future<List<PlacedOrder>> openOrders() async => List.of(b.openOrderRows);

  @override
  Future<PlacedOrder> refresh(String orderId) async {
    final found = b.openOrderRows.where((o) => o.id == orderId).firstOrNull;
    if (found != null) return found;
    throw const AppFailure('Order not found.', kind: FailureKind.rejected);
  }

  @override
  Future<PlacedOrder> setStatus(
    PlacedOrder order,
    PosStatus status, {
    String? reason,
  }) async => order.copyWith(status: status);

  @override
  Future<PlacedOrder> adjustBill(
    PlacedOrder order, {
    required bool waiveServiceCharge,
    String? reason,
  }) async {
    if (b.failAdjustBill != null) throw b.failAdjustBill!;
    b.adjustments.add((
      orderId: order.id,
      waive: waiveServiceCharge,
      reason: reason,
      version: order.version,
    ));
    // Like the server: recompute from the order's own lines and the
    // organization's rates, and hand back a new version.
    final bill = BillSummary.of(
      order.lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
      charges: b.billCharges,
      discount: order.bill.discount,
      waiveServiceCharge: waiveServiceCharge,
    );
    return order.copyWith(bill: bill, version: '${order.version}+');
  }
}

class _Inbox implements DeliveryInbox {
  _Inbox(this.b);
  final FakeBackend b;

  @override
  bool get available => b.inboxAvailable;

  @override
  String? get unavailableReason =>
      b.inboxAvailable ? null : 'No One Local server in this build.';

  @override
  Future<OutletStatus> outlet() async => b.outletStatus;

  @override
  Future<OutletStatus> setAccepting(bool accepting, {DateTime? backAt}) async {
    if (b.failOutletChange != null) throw b.failOutletChange!;
    return b.outletStatus = OutletStatus(accepting: accepting, backAt: backAt);
  }

  @override
  Future<List<DeliveryOrder>> list(InboxTab tab) async =>
      b.deliveries.where((o) => tab.statuses.contains(o.status)).toList();

  @override
  Future<DeliveryOrder> detail(String orderId) async =>
      b.deliveries.firstWhere((o) => o.id == orderId);

  DeliveryOrder _set(
    DeliveryOrder o,
    DeliveryStatus s, {
    int? prep,
    String? reason,
  }) {
    final current = b.deliveries.firstWhere((d) => d.id == o.id);
    if (current.version != o.version) {
      throw const AppFailure(
        'This order was already changed on another phone.',
        kind: FailureKind.conflict,
      );
    }
    final updated = current.copyWith(
      status: s,
      prepMinutes: prep,
      cancelReason: reason,
      version: '${o.version}+',
    );
    b.deliveries[b.deliveries.indexOf(current)] = updated;
    return updated;
  }

  @override
  Future<DeliveryOrder> accept(
    DeliveryOrder order, {
    required int prepMinutes,
  }) async => _set(order, DeliveryStatus.accepted, prep: prepMinutes);

  @override
  Future<DeliveryOrder> reject(
    DeliveryOrder order, {
    required String reason,
  }) async =>
      _set(order, DeliveryStatus.cancelled, reason: 'Restaurant: $reason');

  @override
  Future<DeliveryOrder> markReady(DeliveryOrder order) async =>
      _set(order, DeliveryStatus.packed);

  @override
  Future<DeliveryOrder> markOut(DeliveryOrder order) async =>
      _set(order, DeliveryStatus.out);

  @override
  Future<DeliveryOrder> markDelivered(DeliveryOrder order) async =>
      _set(order, DeliveryStatus.delivered);

  @override
  Future<String> sendTestOrder() async => 'test';
}

class _Storefront implements StorefrontRepository {
  _Storefront(this.b);
  final FakeBackend b;

  @override
  Future<StorefrontState> load(Organization org) async => b.storefrontState;

  @override
  Future<void> saveDraft(Organization org, StorefrontDefinition draft) async =>
      b.storefrontState = StorefrontState(
        draft: draft,
        published: b.storefrontState.published,
        history: b.storefrontState.history,
      );

  @override
  Future<void> discardDraft(Organization org) async =>
      b.storefrontState = StorefrontState(
        published: b.storefrontState.published,
        history: b.storefrontState.history,
      );

  @override
  Future<StorefrontVersion> publish(
    Organization org,
    StorefrontDefinition definition, {
    required String publishedBy,
  }) async {
    if (b.failStorefrontPublish != null) throw b.failStorefrontPublish!;
    final v = StorefrontVersion(
      version: (b.storefrontState.published?.version ?? 0) + 1,
      definition: definition,
      publishedAt: DateTime(2026, 9, 28),
      publishedBy: publishedBy,
    );
    b.storefrontState = StorefrontState(
      published: v,
      history: [v, ...b.storefrontState.history],
    );
    return v;
  }
}

class _BillSettings implements BillSettingsRepository {
  _BillSettings(this.b);
  final FakeBackend b;

  @override
  Future<BillSettings> load() async => b.billSettingsRow;

  @override
  Future<BillSettings> save(BillSettings settings) async {
    if (b.failBillSettingsSave != null) throw b.failBillSettingsSave!;
    if (settings.updatedAt != b.billSettingsRow.updatedAt) {
      throw const AppFailure(
        'Someone else saved these settings while you were editing. '
        'Reload to see their changes, then make yours again.',
        kind: FailureKind.conflict,
      );
    }
    b.billSettingsSaves.add(settings);
    b.billSettingsRow = settings.copyWith(updatedAt: 'v${++b._billVersion}');
    return b.billSettingsRow;
  }
}

class _Team implements TeamRepository {
  _Team(this.b);
  final FakeBackend b;

  @override
  Future<List<TeamMember>> members() async => List.of(b.teamMembers);

  @override
  Future<List<StaffRole>> roles() async => List.of(b.staffRoles);

  Future<TeamMember> _replace(
    TeamMember was,
    TeamMember now,
    String what,
  ) async {
    if (b.failTeamChange != null) throw b.failTeamChange!;
    b.teamChanges.add(what);
    b.teamMembers = [for (final m in b.teamMembers) m.id == was.id ? now : m];
    return now;
  }

  @override
  Future<TeamMember> setRole(TeamMember member, StaffRole role) => _replace(
    member,
    member.copyWith(role: role),
    '${member.id}:role:${role.slug}',
  );

  @override
  Future<TeamMember> setStatus(TeamMember member, {required bool active}) =>
      _replace(
        member,
        member.copyWith(active: active),
        '${member.id}:${active ? 'active' : 'suspended'}',
      );
}

class _Tables implements TablesRepository {
  _Tables(this.b);
  final FakeBackend b;

  @override
  Future<List<TableCode>> list() async => List.of(b.tableCodeRows);

  @override
  Future<TableCode> issueCode(TableCode table, {bool replace = false}) async {
    if (b.failIssueCode != null) throw b.failIssueCode!;
    if (table.hasCode && !replace) {
      throw const AppFailure(
        'This table already has a code.',
        kind: FailureKind.conflict,
      );
    }
    // Ten characters, a-z and 0-9, like the server's.
    final token = 'issued${(++b.issuedCodes).toString().padLeft(4, '0')}';
    final issued = TableCode(
      id: table.id,
      label: table.label,
      seats: table.seats,
      areaId: table.areaId,
      areaName: table.areaName,
      isActive: table.isActive,
      qrToken: token,
      sortOrder: table.sortOrder,
    );
    b.tableCodeRows = [
      for (final t in b.tableCodeRows) t.id == table.id ? issued : t,
    ];
    return issued;
  }
}

class _Channels implements ChannelsRepository {
  _Channels(this.b);
  final FakeBackend b;

  @override
  Future<List<SalesChannel>> list() async => List.of(b.channelRows);

  @override
  Future<SalesChannel> setAccepting(
    SalesChannel channel,
    bool accepting,
  ) async {
    if (b.failChannelChange != null) throw b.failChannelChange!;
    final next = channel.copyWith(accepting: accepting);
    b.channelRows = [
      for (final c in b.channelRows) c.id == channel.id ? next : c,
    ];
    return next;
  }
}
