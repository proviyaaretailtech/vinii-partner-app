import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../core/failure.dart';
import '../../domain/organization.dart';
import '../backend.dart';
import '../local_prefs.dart';
import 'caller_client.dart';
import 'live_auth.dart';
import 'live_bill_settings.dart';
import 'live_channels.dart';
import 'live_menu.dart';
import 'live_pos.dart';
import 'live_storefront.dart';
import 'live_tables.dart';
import 'live_team.dart';
import 'live_workspace.dart';
import 'partner_api_inbox.dart';

/// Supabase for identity and the organization's own rows; One Local's
/// partner API for marketplace delivery orders. The only backend the app
/// ships with — there is no sample data.
class LiveBackend implements Backend {
  /// [client] is for tests that check the exact requests the app makes; the
  /// app itself always uses the one `Supabase.initialize` creates.
  LiveBackend(this.config, this.prefs, {this._client});

  final AppConfig config;
  final LocalPrefs prefs;
  final SupabaseClient? _client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  /// The organization every scoped repository acts on. Reads always filter
  /// by it explicitly, never relying on the database's "your organization".
  Organization? activeOrganization;

  Organization get org =>
      activeOrganization ??
      (throw const AppFailure(
        'Choose an organization first.',
        kind: FailureKind.rejected,
      ));

  /// Contract R7: every request says who is calling. [CallerClient] adds
  /// these plus a fresh `x-request-id` to every Supabase and partner call.
  late final CallerClient http = CallerClient(() => callerHeaders);

  Map<String, String> get callerHeaders => {
    'x-app': 'vinii-partner',
    'x-app-version': AppConfig.appVersion,
    'x-platform': kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
    'x-runtime': AppConfig.buildNumber,
  };

  @override
  late final AuthGateway auth = LiveAuth(this);
  @override
  late final WorkspaceRepository workspace = LiveWorkspace(this);
  @override
  late final MenuRepository menu = LiveMenu(this);
  @override
  late final PosRepository pos = LivePos(this);
  @override
  late final DeliveryInbox inbox = PartnerApiInbox(this, client: http);
  @override
  late final StorefrontRepository storefront = LiveStorefront(this);
  @override
  late final BillSettingsRepository billSettings = LiveBillSettings(this);
  @override
  late final TeamRepository team = LiveTeam(this);
  @override
  late final TablesRepository tableCodes = LiveTables(this);
  @override
  late final ChannelsRepository channels = LiveChannels(this);

  var _started = false;

  @override
  Future<void> start() async {
    if (_started) return;
    if (!config.isConfigured) {
      throw AppFailure(
        'This build is missing ${config.missingSettings.join(' and ')}.',
        kind: FailureKind.notReady,
      );
    }
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabasePublishableKey,
      httpClient: http,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _started = true;
  }

  /// The signed-in person's display name, for event rows ("accepted by").
  String get actorName {
    final u = client.auth.currentUser;
    final meta = u?.userMetadata ?? const {};
    return (meta['full_name'] ?? meta['name'] ?? u?.email ?? 'Staff')
        .toString();
  }
}
