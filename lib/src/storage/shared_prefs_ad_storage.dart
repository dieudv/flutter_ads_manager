import 'package:shared_preferences/shared_preferences.dart';

import 'ad_storage.dart';

class SharedPrefsAdStorage implements AdStorage {
  SharedPrefsAdStorage({this.prefix = 'ads_manager_'});

  final String prefix;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<int?> getInt(String key) async => (await _prefs).getInt('$prefix$key');
  @override
  Future<void> setInt(String key, int value) async => (await _prefs).setInt('$prefix$key', value);
  @override
  Future<String?> getString(String key) async => (await _prefs).getString('$prefix$key');
  @override
  Future<void> setString(String key, String value) async => (await _prefs).setString('$prefix$key', value);
  @override
  Future<void> remove(String key) async => (await _prefs).remove('$prefix$key');
}
