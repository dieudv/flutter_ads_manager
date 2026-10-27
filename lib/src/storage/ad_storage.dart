/// Lưu trữ key-value tối thiểu mà AdPolicy cần. Có thể thay bằng
/// Hive/SecureStorage... bằng cách implement interface này.
abstract class AdStorage {
  Future<int?> getInt(String key);
  Future<void> setInt(String key, int value);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// Storage trong bộ nhớ, dùng cho unit test.
class MemoryAdStorage implements AdStorage {
  final Map<String, Object> data = {};

  @override
  Future<int?> getInt(String key) async => data[key] as int?;
  @override
  Future<void> setInt(String key, int value) async => data[key] = value;
  @override
  Future<String?> getString(String key) async => data[key] as String?;
  @override
  Future<void> setString(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}
