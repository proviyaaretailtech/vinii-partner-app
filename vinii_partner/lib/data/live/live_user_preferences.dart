import '../backend.dart';
import 'errors.dart';
import 'live_backend.dart';

/// `public.user_preferences` (OS migration 0131): a person reads and writes
/// only their own row (row-level security `user_id = auth.uid()`).
class LiveUserPreferences implements UserPreferencesRepository {
  LiveUserPreferences(this._b);
  final LiveBackend _b;

  @override
  Future<String?> loadLocale(String userId) async {
    try {
      final row = await _b.client
          .from('user_preferences')
          .select('locale')
          .eq('user_id', userId)
          .maybeSingle();
      return row?['locale'] as String?;
    } catch (e) {
      throw fromSupabase(e);
    }
  }

  @override
  Future<void> saveLocale(String userId, String locale) async {
    try {
      await _b.client.from('user_preferences').upsert({
        'user_id': userId,
        'locale': locale,
      }, onConflict: 'user_id');
    } catch (e) {
      throw fromSupabase(e);
    }
  }
}
