import 'package:shared_preferences/shared_preferences.dart';

/// Local flag: has this device confirmed 18+? Self-attestation only, no
/// server round-trip — works offline and for anonymous browsing
/// (PLAN.md §5.3, resolved 2026-08-17).
abstract final class AgeGatePrefs {
  static const _key = 'age_confirmed_18';

  static Future<bool> isConfirmed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> confirm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
