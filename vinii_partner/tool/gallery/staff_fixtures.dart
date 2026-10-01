// Synthetic data for the staff gallery and the visual review test. Every name,
// number and dish below is invented; none of it is read from or written to a
// database. Used only by tool/gallery/staff.dart and tests, never by lib/.
import 'package:vinii_partner/application/outlet_mode.dart';
import 'package:vinii_partner/domain/billing.dart';
import 'package:vinii_partner/domain/delivery_order.dart';
import 'package:vinii_partner/domain/menu.dart';
import 'package:vinii_partner/domain/organization.dart';
import 'package:vinii_partner/domain/pos_order.dart';
import 'package:vinii_partner/domain/staff.dart';

// `flutter run -t tool/gallery/staff.dart` serves tool/gallery and test/ as
// one root, so in the browser build the fake is `support/fake_backend.dart`
// (the second path). The analyzer sees real folders and takes the first.
import '../../test/support/fake_backend.dart'
    if (dart.library.js_interop) 'support/fake_backend.dart';

const galleryRoleNames = {
  'org_owner': 'Organization Owner',
  'org_admin': 'Organization Admin',
  'manager': 'Manager',
  'biller': 'Biller / POS',
  'captain': 'Captain',
  'kitchen': 'KOT / Kitchen',
  'viewer': 'Viewer',
};

const galleryOrg = Organization(
  id: 'gallery-org',
  name: 'Sample Kitchen (gallery)',
  slug: 'sample-kitchen',
  type: 'restaurant',
  accentHex: '#1F2937',
);

/// The signed-in person in the gallery.
const galleryUser = StaffUser(
  id: 'gallery-user',
  email: 'you@sample-kitchen.example',
  fullName: 'Asha Verma',
);

/// A fake backend filled for [role] to review: a menu, tables with codes, a
/// team, bill settings, channels, two delivery orders in progress and two
/// unpaid table orders. [outlet] is `paused` or `closed` to start the store
/// in that state; [service] false starts with no service charge.
FakeBackend staffGalleryBackend({
  Organization org = galleryOrg,
  required String role,
  String? outlet,
  bool service = true,
}) {
  const me = galleryUser;
  final backend = FakeBackend(
    user: me,
    memberships: [
      Membership(
        organization: org,
        roleSlug: role,
        roleName: galleryRoleNames[role]!,
      ),
    ],
    menu: staffGalleryMenu,
    tables: const [
      DiningTable(id: 'tb1', label: 'T1', seats: 2, area: 'Indoor'),
      DiningTable(id: 'tb2', label: 'T2', seats: 4, area: 'Indoor'),
      DiningTable(id: 'tb3', label: 'T3', seats: 4, area: 'Indoor'),
      DiningTable(id: 'tb4', label: 'T4', seats: 6, area: 'Indoor'),
      DiningTable(id: 'tb6', label: 'R1', seats: 4, area: 'Rooftop'),
      DiningTable(id: 'tb7', label: 'R2', seats: 8, area: 'Rooftop'),
    ],
  );

  // Rates the bill uses, and the row the Bill & GST screen edits.
  backend.billCharges = BillCharges(serviceChargePercent: service ? 10 : 0);
  backend.saveBillSettingsElsewhere(
    BillSettings(
      legalName: 'Sample Kitchen Pvt Ltd',
      address: '12 Example Road, Sampletown',
      gstin: '27AAAAA0000A1Z5',
      fssai: '12345678901234',
      phone: '+91 98765 43210',
      serviceChargePercent: service ? 10 : 0,
      footerNote: 'Thank you! Visit again.',
    ),
  );

  backend.billSettingsRow = backend.billSettingsRow.copyWith(
    updatedAt: DateTime.now()
        .subtract(const Duration(days: 2))
        .toUtc()
        .toIso8601String(),
  );

  // The team.
  const roles = [
    StaffRole(id: 'r-owner', slug: 'org_owner', name: 'Organization Owner'),
    StaffRole(id: 'r-admin', slug: 'org_admin', name: 'Organization Admin'),
    StaffRole(id: 'r-manager', slug: 'manager', name: 'Manager'),
    StaffRole(id: 'r-biller', slug: 'biller', name: 'Biller / POS'),
    StaffRole(id: 'r-captain', slug: 'captain', name: 'Captain'),
    StaffRole(id: 'r-kitchen', slug: 'kitchen', name: 'KOT / Kitchen'),
    StaffRole(id: 'r-viewer', slug: 'viewer', name: 'Viewer'),
  ];
  StaffRole r(String slug) => roles.firstWhere((x) => x.slug == slug);
  backend.staffRoles = roles;
  backend.teamMembers = [
    TeamMember(
      id: 'm0',
      userId: me.id,
      email: me.email,
      fullName: me.fullName,
      role: r(role),
    ),
    TeamMember(
      id: 'm1',
      userId: 'u1',
      email: 'neha.shah@sample-kitchen.example',
      fullName: 'Neha Shah',
      role: r('org_admin'),
    ),
    TeamMember(
      id: 'm2',
      userId: 'u2',
      email: 'ravi.kulkarni@sample-kitchen.example',
      fullName: 'Ravi Kulkarni',
      role: r('manager'),
    ),
    TeamMember(
      id: 'm3',
      userId: 'u3',
      email: 'meera.joshi@sample-kitchen.example',
      fullName: 'Meera Joshi',
      role: r('biller'),
    ),
    TeamMember(
      id: 'm4',
      userId: 'u4',
      email: 'sanjay.rao@sample-kitchen.example',
      fullName: 'Sanjay Rao',
      role: r('captain'),
    ),
    TeamMember(
      id: 'm5',
      userId: 'u5',
      email: 'kitchen1@sample-kitchen.example',
      role: r('kitchen'),
    ),
    TeamMember(
      id: 'm6',
      userId: 'u6',
      email: 'priya.d@sample-kitchen.example',
      fullName: 'Priya Deshmukh',
      role: r('biller'),
      active: false,
    ),
    TeamMember(
      id: 'm7',
      userId: 'u7',
      email: 'arjun.p@sample-kitchen.example',
      fullName: 'Arjun Patil',
      role: r('captain'),
    ),
    TeamMember(
      id: 'm8',
      userId: 'u8',
      email: 'kavya.n@sample-kitchen.example',
      fullName: 'Kavya Nair',
      role: r('viewer'),
    ),
  ];

  // Tables and their codes: most have one, two do not, one is out of service.
  backend.tableCodeRows = const [
    TableCode(
      id: 'tb1',
      label: 'T1',
      seats: 2,
      areaName: 'Indoor',
      qrToken: 'gx7k2m9q4a',
    ),
    TableCode(
      id: 'tb2',
      label: 'T2',
      areaName: 'Indoor',
      qrToken: 'p3d8w1n5ze',
      sortOrder: 1,
    ),
    TableCode(
      id: 'tb3',
      label: 'T3',
      areaName: 'Indoor',
      qrToken: 'c6h2t8v0ru',
      sortOrder: 2,
    ),
    TableCode(
      id: 'tb4',
      label: 'T4',
      seats: 6,
      areaName: 'Indoor',
      sortOrder: 3,
    ),
    TableCode(
      id: 'tb5',
      label: 'T5',
      areaName: 'Indoor',
      isActive: false,
      qrToken: 'm9s4b7y1jk',
      sortOrder: 4,
    ),
    TableCode(
      id: 'tb6',
      label: 'R1',
      areaName: 'Rooftop',
      qrToken: 'f5l0q3x8id',
    ),
    TableCode(
      id: 'tb7',
      label: 'R2',
      seats: 8,
      areaName: 'Rooftop',
      sortOrder: 1,
    ),
  ];

  // Sales channels.
  backend.channelRows = const [
    SalesChannel(
      id: 'c1',
      key: 'swiggy',
      name: 'Swiggy',
      connected: true,
      accepting: true,
    ),
    SalesChannel(
      id: 'c2',
      key: 'zomato',
      name: 'Zomato',
      connected: true,
      accepting: false,
    ),
    SalesChannel(
      id: 'c3',
      key: 'website',
      name: 'Website',
      connected: false,
      accepting: true,
    ),
  ];

  // The store, and two delivery orders already being handled (so no alert
  // rings when the gallery opens).
  backend.outletStatus = switch (outlet) {
    'paused' => OutletStatus(
      accepting: false,
      backAt: DateTime.now().add(const Duration(minutes: 30)),
    ),
    'closed' => OutletStatus(accepting: false, backAt: nextOpening()),
    _ => const OutletStatus(accepting: true),
  };
  final now = DateTime.now();
  backend.deliveries.addAll([
    DeliveryOrder(
      id: 'd1',
      displayNo: 'OL-00041',
      status: DeliveryStatus.accepted,
      version: 'v1',
      placedAt: now.subtract(const Duration(minutes: 9)),
      customerName: 'Rahul Patil',
      customerPhone: '98765 00001',
      area: 'Shivaji Nagar',
      prepMinutes: 20,
      items: const [
        DeliveryLine(name: 'Chicken Biryani', qty: 2, price: 280),
        DeliveryLine(
          name: 'Sweet Lassi',
          qty: 1,
          price: 70,
          notes: 'Less sugar',
        ),
      ],
      subtotal: 630,
      gst: 31.5,
      deliveryFee: 30,
      total: 691.5,
    ),
    DeliveryOrder(
      id: 'd2',
      displayNo: 'OL-00040',
      status: DeliveryStatus.packed,
      version: 'v1',
      placedAt: now.subtract(const Duration(minutes: 22)),
      customerName: 'Priya Sharma',
      customerPhone: '98765 00002',
      area: 'Ganesh Nagar',
      items: const [DeliveryLine(name: 'Veg Thali', qty: 1, price: 220)],
      subtotal: 220,
      gst: 11,
      deliveryFee: 30,
      total: 261,
    ),
  ]);

  // Two unpaid table orders for the Open orders list and the payment screen.
  PlacedOrder dineIn(
    String id,
    String no,
    String table,
    List<CartLine> lines, {
    double paid = 0,
    int minutesAgo = 12,
  }) {
    final charges = BillCharges(serviceChargePercent: service ? 10 : 0);
    final bill = BillSummary.of(
      lines.map((l) => (unitPrice: l.unitPrice, qty: l.qty)),
      charges: charges,
    );
    return PlacedOrder(
      id: id,
      version: 'v1',
      displayNo: no,
      status: PosStatus.sentToKitchen,
      serviceType: ServiceType.dineIn,
      createdAt: now.subtract(Duration(minutes: minutesAgo)),
      lines: lines,
      bill: bill,
      table: DiningTable(id: 'x-$table', label: table, seats: 4),
      paidAmount: paid,
    );
  }

  backend.openOrderRows = [
    dineIn('o-101', 'ORD-101', 'T2', const [
      CartLine(
        itemId: 'i-biryani-c',
        name: 'Chicken Biryani',
        unitPrice: 280,
        qty: 2,
      ),
      CartLine(itemId: 'i-lassi', name: 'Sweet Lassi', unitPrice: 70, qty: 2),
      CartLine(
        itemId: 'i-tikka',
        name: 'Paneer Tikka',
        unitPrice: 240,
        notes: 'Extra spicy',
      ),
    ]),
    dineIn(
      'o-102',
      'ORD-102',
      'R1',
      const [
        CartLine(itemId: 'i-thali', name: 'Veg Thali', unitPrice: 220, qty: 3),
        CartLine(itemId: 'i-cola', name: 'Cold Drink', unitPrice: 50, qty: 3),
      ],
      paid: 400,
      minutesAgo: 41,
    ),
  ];
  return backend;
}

// ── A synthetic menu: invented dishes, no photos ───────────────────────────

const staffGalleryMenu = MenuSnapshot(
  categories: [
    MenuCategory(id: 'c-starters', name: 'Starters', sortOrder: 0),
    MenuCategory(id: 'c-biryani', name: 'Biryani', sortOrder: 1),
    MenuCategory(id: 'c-thali', name: 'Thalis', sortOrder: 2),
    MenuCategory(id: 'c-drinks', name: 'Drinks', sortOrder: 3),
  ],
  items: [
    MenuItem(
      id: 'i-tikka',
      name: 'Paneer Tikka',
      price: 240,
      categoryId: 'c-starters',
      foodType: FoodType.veg,
    ),
    MenuItem(
      id: 'i-corn',
      name: 'Crispy Corn',
      price: 160,
      categoryId: 'c-starters',
      foodType: FoodType.veg,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i-c65',
      name: 'Chicken 65',
      price: 260,
      categoryId: 'c-starters',
      foodType: FoodType.nonVeg,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i-egg',
      name: 'Egg Masala Fry',
      price: 140,
      categoryId: 'c-starters',
      foodType: FoodType.egg,
      sortOrder: 3,
    ),
    MenuItem(
      id: 'i-biryani-c',
      name: 'Chicken Biryani',
      price: 280,
      categoryId: 'c-biryani',
      foodType: FoodType.nonVeg,
    ),
    MenuItem(
      id: 'i-biryani-m',
      name: 'Mutton Biryani',
      price: 360,
      categoryId: 'c-biryani',
      foodType: FoodType.nonVeg,
      sortOrder: 1,
      isAvailable: false,
    ),
    MenuItem(
      id: 'i-biryani-v',
      name: 'Veg Dum Biryani',
      price: 220,
      categoryId: 'c-biryani',
      foodType: FoodType.veg,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i-thali',
      name: 'Veg Thali',
      price: 220,
      categoryId: 'c-thali',
      foodType: FoodType.veg,
    ),
    MenuItem(
      id: 'i-thali-n',
      name: 'Non-veg Thali',
      price: 320,
      categoryId: 'c-thali',
      foodType: FoodType.nonVeg,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i-dal',
      name: 'Dal Tadka with Rice',
      price: 170,
      categoryId: 'c-thali',
      foodType: FoodType.veg,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i-lassi',
      name: 'Sweet Lassi',
      price: 70,
      categoryId: 'c-drinks',
      foodType: FoodType.veg,
    ),
    MenuItem(
      id: 'i-cola',
      name: 'Cold Drink',
      price: 50,
      categoryId: 'c-drinks',
      foodType: FoodType.veg,
      sortOrder: 1,
    ),
    MenuItem(
      id: 'i-lime',
      name: 'Fresh Lime Soda',
      price: 80,
      categoryId: 'c-drinks',
      foodType: FoodType.veg,
      sortOrder: 2,
    ),
    MenuItem(
      id: 'i-coffee',
      name: 'Filter Coffee',
      price: 60,
      categoryId: 'c-drinks',
      foodType: FoodType.veg,
      sortOrder: 3,
    ),
  ],
);
