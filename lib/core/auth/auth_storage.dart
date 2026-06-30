// lib/core/auth/auth_storage.dart
//
// Persists the auth session (JWT access/refresh tokens + identity) so a web page
// refresh or app relaunch keeps the user logged in.
//
// Backed by flutter_secure_storage so the TOKENS are NOT in plaintext: iOS Keychain,
// Android Keystore-encrypted values, and a WebCrypto-backed store on web. This is pure
// storage — no business logic; AuthSession is the in-memory source of truth and uses
// this to save/restore. The save/read/clear interface is unchanged from the previous
// shared_preferences backing, so callers didn't change.
//
// NOTE: this is a backend change of WHERE tokens live, so any session previously stored
// in plaintext shared_preferences won't be found here — affected users simply log in
// once more (a one-time, acceptable cost for moving secrets out of plaintext).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _secure = FlutterSecureStorage();

  static const _kAccess = 'auth.accessToken';
  static const _kRefresh = 'auth.refreshToken';
  static const _kUserId = 'auth.userId';
  static const _kRole = 'auth.role';
  static const _kOrg = 'auth.organisationId';
  static const _kGroup = 'auth.groupId';

  static const _keys = [_kAccess, _kRefresh, _kUserId, _kRole, _kOrg, _kGroup];

  static Future<void> save({
    String? accessToken,
    String? refreshToken,
    String? userId,
    String? role,
    String? organisationId,
    String? groupId,
  }) async {
    Future<void> set(String k, String? v) =>
        (v == null || v.isEmpty) ? _secure.delete(key: k) : _secure.write(key: k, value: v);
    await set(_kAccess, accessToken);
    await set(_kRefresh, refreshToken);
    await set(_kUserId, userId);
    await set(_kRole, role);
    await set(_kOrg, organisationId);
    await set(_kGroup, groupId);
  }

  static Future<Map<String, String?>> read() async {
    return {
      'accessToken': await _secure.read(key: _kAccess),
      'refreshToken': await _secure.read(key: _kRefresh),
      'userId': await _secure.read(key: _kUserId),
      'role': await _secure.read(key: _kRole),
      'organisationId': await _secure.read(key: _kOrg),
      'groupId': await _secure.read(key: _kGroup),
    };
  }

  static Future<void> clear() async {
    for (final k in _keys) {
      await _secure.delete(key: k);
    }
  }
}
