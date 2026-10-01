import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vinii_partner/app/app_scope.dart';
import 'package:vinii_partner/application/team_controller.dart';
import 'package:vinii_partner/core/failure.dart';
import 'package:vinii_partner/domain/staff.dart';
import 'package:vinii_partner/presentation/team/team_screen.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _owner = StaffRole(
  id: 'r1',
  slug: 'org_owner',
  name: 'Organization Owner',
);
const _admin = StaffRole(
  id: 'r2',
  slug: 'org_admin',
  name: 'Organization Admin',
);
const _manager = StaffRole(id: 'r3', slug: 'manager', name: 'Manager');
const _biller = StaffRole(id: 'r4', slug: 'biller', name: 'Biller / POS');
const _captain = StaffRole(id: 'r5', slug: 'captain', name: 'Captain');
const _kitchen = StaffRole(id: 'r6', slug: 'kitchen', name: 'KOT / Kitchen');
const _viewer = StaffRole(id: 'r7', slug: 'viewer', name: 'Viewer');
const _roles = [_owner, _admin, _manager, _biller, _captain, _kitchen, _viewer];

const _me = TeamMember(
  id: 'm1',
  userId: 'u-1',
  email: 'asha@example.com',
  fullName: 'Asha Verma',
  role: _admin,
);
const _ravi = TeamMember(
  id: 'm2',
  userId: 'u-2',
  email: 'ravi@example.com',
  fullName: 'Ravi Kulkarni',
  role: _manager,
);
const _meera = TeamMember(
  id: 'm3',
  userId: 'u-3',
  email: 'meera@example.com',
  fullName: 'Meera Joshi',
  role: _biller,
);
const _sanjay = TeamMember(
  id: 'm4',
  userId: 'u-4',
  email: 'sanjay@example.com',
  fullName: 'Sanjay Rao',
  role: _captain,
);
const _kitchenOnly = TeamMember(
  id: 'm5',
  userId: 'u-5',
  email: 'kitchen1@example.com',
  role: _kitchen,
);
const _priya = TeamMember(
  id: 'm6',
  userId: 'u-6',
  email: 'priya@example.com',
  fullName: 'Priya Deshmukh',
  role: _biller,
  active: false,
);
const _neha = TeamMember(
  id: 'm7',
  userId: 'u-7',
  email: 'neha@example.com',
  fullName: 'Neha Shah',
  role: _admin,
);
const _seven = [_me, _ravi, _meera, _sanjay, _kitchenOnly, _priya, _neha];

FakeBackend _backend([List<TeamMember> members = _seven]) => FakeBackend()
  ..teamMembers = [...members]
  ..staffRoles = [..._roles];

Future<(AppServices, FakeBackend)> _open(
  WidgetTester tester, {
  String role = 'org_admin',
  FakeBackend? backend,
}) async {
  tester.view.physicalSize = const Size(1170, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  final b = backend ?? _backend();
  final services = await testServices(b);
  services.session.membership = membershipAs(role);
  services.session.user = const StaffUser(id: 'u-1', email: 'asha@example.com');
  // Start from nothing, so a second screen in one test builds afresh.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(wrapScreen(services, const TeamScreen()));
  await tester.pumpAndSettle();
  return (services, b);
}

void main() {
  group('what a role can do, in plain words', () {
    test('it is built from the same table the buttons use', () {
      expect(
        roleSummary('org_admin'),
        'Can manage the team, change the bill and GST settings, publish the '
        'guest storefront and more.',
      );
      expect(
        roleSummary('manager'),
        'Can edit the guest storefront, edit the menu, change the store '
        'status and more.',
      );
      expect(
        roleSummary('biller'),
        'Can take payments, take table orders, accept delivery orders and more.',
      );
      expect(
        roleSummary('captain'),
        'Can take table orders, see delivery orders and see the menu.',
      );
      expect(
        roleSummary('kitchen'),
        'Can mark food ready, see delivery orders and see the menu.',
      );
      expect(roleSummary('viewer'), 'Can see delivery orders.');
    });

    test('a role with nothing in this app says so', () {
      expect(
        roleSummary('accountant'),
        'Cannot use Orders, Sell or Menu in this app.',
      );
    });

    test('only an organization admin may manage the team', () {
      for (final slug in ['org_owner', 'manager', 'biller', 'viewer']) {
        expect(
          membershipAs(slug).can(Capability.manageTeam),
          isFalse,
          reason: slug,
        );
        expect(
          membershipAs(slug).can(Capability.viewTeam),
          isTrue,
          reason: slug,
        );
      }
      expect(membershipAs('org_admin').can(Capability.manageTeam), isTrue);
    });
  });

  group('the guards', () {
    TeamController controller(
      List<TeamMember> members, {
      String me = 'u-1',
      bool canManage = true,
    }) {
      final b = _backend(members);
      return TeamController(
        repository: b.team,
        meUserId: me,
        canManage: canManage,
      );
    }

    test('nobody changes or suspends themselves', () async {
      final c = controller(_seven);
      await c.load();
      expect(c.whyNoRoleChange(_me), 'You cannot change your own role.');
      expect(c.whyNoSuspend(_me), 'You cannot suspend yourself.');
      expect(c.whyNoRoleChange(_ravi), isNull);
      expect(c.whyNoSuspend(_ravi), isNull);
      await expectLater(c.setActive(_me, false), throwsA(isA<AppFailure>()));
    });

    test('the last active admin can neither be demoted nor suspended', () async {
      final c = controller([_me, _ravi, _priya], me: 'someone-else');
      await c.load();
      const why =
          'There must always be one active admin. Make someone else an admin first.';
      expect(c.whyNoRoleChange(_me, to: _manager), why);
      expect(c.whyNoSuspend(_me), why);
      expect(
        c.whyNoRoleChange(_me, to: _admin),
        isNull,
        reason: 'staying an admin is fine',
      );
    });

    test('with two admins either may be changed by the other', () async {
      final c = controller([_me, _neha, _ravi], me: 'someone-else');
      await c.load();
      expect(c.whyNoSuspend(_neha), isNull);
      expect(c.whyNoRoleChange(_neha, to: _manager), isNull);
    });

    test('a suspended admin does not count as an active one', () async {
      final c = controller([
        _me,
        _neha.copyWith(active: false),
      ], me: 'someone-else');
      await c.load();
      expect(c.whyNoSuspend(_me), isNotNull);
    });

    test('without the right to manage, nothing can be changed', () async {
      final c = controller(_seven, canManage: false);
      await c.load();
      expect(c.whyNoRoleChange(_ravi), isNotNull);
      expect(c.whyNoSuspend(_ravi), isNotNull);
      await expectLater(c.setRole(_ravi, _biller), throwsA(isA<AppFailure>()));
    });
  });

  group('the Team screen', () {
    testWidgets('lists the real team: initials, name or email, role, status', (
      tester,
    ) async {
      await _open(tester);

      expect(find.text('7 people · 6 active'), findsOneWidget);
      expect(find.text('Asha Verma'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('AV'), findsOneWidget);
      expect(find.text('Ravi Kulkarni'), findsOneWidget);
      // No name on file: the email stands in, and appears once.
      expect(find.text('kitchen1@example.com'), findsOneWidget);
      expect(find.text('K'), findsOneWidget);
      expect(find.text('Active'), findsNWidgets(6));
      expect(find.text('Suspended'), findsOneWidget);
      expect(find.textContaining('Can take payments'), findsWidgets);
      expect(
        find.textContaining('Can mark food ready, see delivery orders'),
        findsOneWidget,
      );
    });

    testWidgets('what each role can do is said once, not on every row', (
      tester,
    ) async {
      await _open(tester);

      expect(find.byKey(const Key('team-roles-legend')), findsOneWidget);
      expect(find.text('What each role can do'), findsOneWidget);
      // One line per role in use, in the order a restaurant thinks of them.
      expect(
        find.textContaining('Can take payments, take table orders'),
        findsOneWidget,
        reason: 'the Biller line, once, although two people are billers',
      );
      expect(find.textContaining('Can mark food ready'), findsOneWidget);
    });

    testWidgets('filtering by a role shows what that role can do', (
      tester,
    ) async {
      await _open(tester);
      expect(find.byKey(const Key('team-filter-summary')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('team-filter-captain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-filter-captain')));
      await tester.pumpAndSettle();

      final summary = tester.widget<Text>(
        find.byKey(const Key('team-filter-summary')),
      );
      expect(
        summary.textSpan!.toPlainText(),
        'Captain: Can take table orders, see delivery orders and see the menu.',
      );
    });

    testWidgets('filter by role, then show everyone again', (tester) async {
      await _open(tester);

      expect(find.byKey(const Key('team-filter-all')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('team-filter-biller')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-filter-biller')));
      await tester.pumpAndSettle();
      expect(find.text('Meera Joshi'), findsOneWidget);
      expect(find.text('Priya Deshmukh'), findsOneWidget);
      expect(find.text('Ravi Kulkarni'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('team-filter-all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Ravi Kulkarni'), findsOneWidget);
    });

    testWidgets('search appears only when the team is long', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('team-search')), findsNothing);

      final many = [
        ..._seven,
        for (var i = 0; i < 3; i++)
          TeamMember(
            id: 'x$i',
            userId: 'ux$i',
            email: 'helper$i@example.com',
            fullName: 'Helper $i',
            role: _captain,
          ),
      ];
      await _open(tester, backend: _backend(many));
      expect(find.byKey(const Key('team-search')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('team-search')), 'helper 2');
      await tester.pumpAndSettle();
      expect(find.text('Helper 2'), findsOneWidget);
      expect(find.text('Helper 1'), findsNothing);
      expect(find.text('Ravi Kulkarni'), findsNothing);

      await tester.enterText(find.byKey(const Key('team-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Nobody matches'), findsOneWidget);
      await tester.tap(find.text('Show everyone'));
      await tester.pumpAndSettle();
      expect(find.text('Ravi Kulkarni'), findsOneWidget);
    });

    testWidgets('everyone but an admin sees a read-only list', (tester) async {
      for (final role in ['org_owner', 'manager', 'kitchen']) {
        await _open(tester, role: role);
        expect(
          find.text(
            'Only an organization admin can change roles or suspend people.',
          ),
          findsOneWidget,
          reason: role,
        );
        expect(
          find.byKey(const Key('team-invite')),
          findsNothing,
          reason: role,
        );
        expect(
          find.byIcon(Icons.chevron_right_rounded),
          findsNothing,
          reason: role,
        );
        await tester.tap(find.text('Ravi Kulkarni'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('team-change-role')),
          findsNothing,
          reason: role,
        );
      }
    });

    testWidgets('a role that may not look is told so', (tester) async {
      await _open(tester, role: 'custom_role');
      expect(find.text('Not available for your role'), findsOneWidget);
    });

    testWidgets('an empty team says so, plainly', (tester) async {
      await _open(tester, backend: _backend(const []));
      expect(find.text('No one is listed yet'), findsOneWidget);
      expect(find.text('Ravi Kulkarni'), findsNothing);
    });

    testWidgets('Invite staff explains where invitations come from', (
      tester,
    ) async {
      await _open(tester);

      await tester.tap(find.byKey(const Key('team-invite')));
      await tester.pumpAndSettle();

      expect(find.text('Invite staff'), findsNWidgets(2)); // button + sheet
      expect(find.textContaining('VINII control panel'), findsOneWidget);
      expect(find.textContaining('Users & Roles'), findsOneWidget);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.text('Got it'), findsNothing);
    });

    testWidgets('an admin changes a role: choose, confirm, done', (
      tester,
    ) async {
      final (_, backend) = await _open(tester);

      await tester.tap(find.text('Ravi Kulkarni'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-change-role')));
      await tester.pumpAndSettle();

      expect(find.text('Change role for Ravi Kulkarni'), findsOneWidget);
      expect(find.text('Manager (now)'), findsOneWidget);
      expect(find.textContaining('Can take table orders'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('team-role-confirm')))
            .onPressed,
        isNull,
        reason: 'nothing chosen yet',
      );

      await tester.tap(find.byKey(const Key('team-role-kitchen')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make KOT / Kitchen'));
      await tester.pumpAndSettle();

      expect(backend.teamChanges, ['m2:role:kitchen']);
      expect(find.text('Ravi Kulkarni is now KOT / Kitchen.'), findsOneWidget);
      expect(
        backend.teamMembers.firstWhere((m) => m.id == 'm2').role.slug,
        'kitchen',
      );
    });

    testWidgets('suspending asks first and says what it means', (tester) async {
      final (_, backend) = await _open(tester);

      await tester.tap(find.text('Meera Joshi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-suspend')));
      await tester.pumpAndSettle();
      expect(find.text('Suspend Meera Joshi?'), findsOneWidget);
      expect(find.textContaining('Nothing is deleted'), findsOneWidget);
      expect(backend.teamChanges, isEmpty);

      await tester.tap(find.byKey(const Key('team-suspend-confirm')));
      await tester.pumpAndSettle();

      expect(backend.teamChanges, ['m3:suspended']);
      expect(find.text('Meera Joshi is suspended.'), findsOneWidget);
      expect(find.text('7 people · 5 active'), findsOneWidget);
      expect(find.text('Suspended'), findsNWidgets(2));
    });

    testWidgets('a suspended person can be reactivated', (tester) async {
      final (_, backend) = await _open(tester);

      await tester.tap(find.text('Priya Deshmukh'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('team-suspend')), findsNothing);
      await tester.tap(find.byKey(const Key('team-reactivate')));
      await tester.pumpAndSettle();
      expect(find.text('Reactivate Priya Deshmukh?'), findsOneWidget);
      expect(backend.teamChanges, isEmpty, reason: 'asks first');
      await tester.tap(find.byKey(const Key('team-reactivate-confirm')));
      await tester.pumpAndSettle();

      expect(backend.teamChanges, ['m6:active']);
      expect(find.text('Priya Deshmukh is active again.'), findsOneWidget);
      expect(find.text('7 people'), findsOneWidget);
    });

    testWidgets('you cannot change or suspend yourself', (tester) async {
      final (_, backend) = await _open(tester);

      await tester.tap(find.text('Asha Verma'));
      await tester.pumpAndSettle();

      expect(find.text('You cannot change your own role.'), findsOneWidget);
      expect(find.text('You cannot suspend yourself.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('team-suspend')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Suspend Asha'), findsNothing);
      expect(backend.teamChanges, isEmpty);
    });

    testWidgets('the database refusing is shown, and the list is unchanged', (
      tester,
    ) async {
      final backend = _backend()
        ..failTeamChange = const AppFailure(
          'Only an organization admin can change the team.',
          kind: FailureKind.forbidden,
        );
      await _open(tester, backend: backend);

      await tester.tap(find.text('Sanjay Rao'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-suspend')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('team-suspend-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text('Only an organization admin can change the team.'),
        findsOneWidget,
      );
      expect(find.text('Suspended'), findsOneWidget); // still just Priya
    });
  });
}
