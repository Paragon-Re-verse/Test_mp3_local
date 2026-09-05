import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the prototype kept in component state and that needs to
/// survive an app restart: folder, theme/colour/lang, per-track custom tags,
/// the tag vocabulary, network identity, and per-device "don't ask again"
/// sync preferences. Persisted as one JSON blob, mirroring how compact the
/// prototype's own state object was.
class AppStore {
  final SharedPreferences _prefs;
  final String _key;
  AppStore._(this._prefs, this._key);

  /// [keySuffix] isolates storage under a distinct key - only meaningful in
  /// tests that run multiple "devices" (multiple AppStore instances) against
  /// one shared mocked SharedPreferences store in a single process.
  static Future<AppStore> load({String keySuffix = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return AppStore._(prefs, 'nocturne_settings_v1$keySuffix');
  }

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, dynamic> data) async {
    await _prefs.setString(_key, jsonEncode(data));
  }

  Future<T> _get<T>(String field, T fallback) async {
    final data = _read();
    return (data[field] as T?) ?? fallback;
  }

  Future<void> _set(String field, dynamic value) async {
    final data = _read();
    data[field] = value;
    await _write(data);
  }

  Future<String?> get folder async => (_read()['folder'] as String?);
  Future<void> setFolder(String path) => _set('folder', path);

  Future<String> get theme async => _get('theme', 'system');
  Future<void> setTheme(String v) => _set('theme', v);

  Future<String> get colorChoice async => _get('color', 'system');
  Future<void> setColorChoice(String v) => _set('color', v);

  Future<String> get customHex async => _get('custom', '#7fb2a1');
  Future<void> setCustomHex(String v) => _set('custom', v);

  Future<String> get lang async => _get('lang', 'ru');
  Future<void> setLang(String v) => _set('lang', v);

  Future<bool> get transcode async => _get('transcode', true);
  Future<void> setTranscode(bool v) => _set('transcode', v);

  Future<String> get deviceName async => _get('devName', await _defaultDeviceName());
  Future<void> setDeviceName(String v) => _set('devName', v);

  Future<String> _defaultDeviceName() async {
    final existing = (_read()['devName'] as String?);
    if (existing != null) return existing;
    final generated = 'Nocturne-${(1000 + (DateTime.now().millisecondsSinceEpoch % 9000))}';
    await _set('devName', generated);
    return generated;
  }

  Future<List<String>> get allTags async =>
      ((_read()['allTags'] as List?)?.cast<String>()) ??
      const ['Дорога', 'Вечер', 'Работа', 'Тихое', 'Бодрое'];
  Future<void> setAllTags(List<String> tags) => _set('allTags', tags);

  /// trackId (file path) -> list of tag names.
  Future<Map<String, List<String>>> get trackTags async {
    final raw = (_read()['trackTags'] as Map?) ?? {};
    return raw.map((k, v) => MapEntry(k as String, (v as List).cast<String>()));
  }

  Future<void> setTrackTags(Map<String, List<String>> map) =>
      _set('trackTags', map.map((k, v) => MapEntry(k, v)));

  /// trackId -> custom cover file path (overrides embedded ID3 cover).
  Future<Map<String, String>> get trackCoverOverrides async {
    final raw = (_read()['trackCovers'] as Map?) ?? {};
    return raw.map((k, v) => MapEntry(k as String, v as String));
  }

  Future<void> setTrackCoverOverrides(Map<String, String> map) =>
      _set('trackCovers', map);

  /// Paired device (single active pairing, matching the prototype).
  Future<Map<String, dynamic>?> get pairedDevice async =>
      (_read()['paired'] as Map<String, dynamic>?);
  Future<void> setPairedDevice(Map<String, dynamic>? device) =>
      _set('paired', device);

  Future<Set<String>> get dontAskDeviceIds async =>
      ((_read()['dontAsk'] as List?)?.cast<String>().toSet()) ?? {};
  Future<void> setDontAskDeviceIds(Set<String> ids) =>
      _set('dontAsk', ids.toList());

  Future<String> get networkIdentity async => _get('netId', '');
  Future<void> setNetworkIdentity(String id) => _set('netId', id);

  Future<bool> get netOn async => _get('netOn', true);
  Future<void> setNetOn(bool v) => _set('netOn', v);
}
