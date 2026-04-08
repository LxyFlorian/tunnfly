import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'crypto_service.dart';

/// Manages the user's key pair: generation, persistence, and retrieval.
/// Private key is stored locally in secure storage (never sent to server).
/// Public key is stored in Supabase profiles table.
class KeyManager {
  static const _privateKeyStorageKey = 'tunnfly_private_key';
  static const _publicKeyStorageKey = 'tunnfly_public_key';

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;

  KeyManager({
    FlutterSecureStorage? secureStorage,
    CryptoService? cryptoService,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _cryptoService = cryptoService ?? CryptoService();

  /// Returns true if a key pair already exists in secure storage.
  Future<bool> hasKeyPair() async {
    final privateKey = await _secureStorage.read(key: _privateKeyStorageKey);
    return privateKey != null;
  }

  /// Generates a new key pair, stores the private key locally,
  /// and returns the public key as base64 for Supabase.
  Future<String> generateAndStoreKeyPair() async {
    final keyPair = await _cryptoService.generateKeyPair();
    final privateKeyBase64 = await _cryptoService.exportPrivateKey(keyPair);
    final publicKeyBase64 = await _cryptoService.exportPublicKey(keyPair);

    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: privateKeyBase64,
    );
    await _secureStorage.write(
      key: _publicKeyStorageKey,
      value: publicKeyBase64,
    );

    return publicKeyBase64;
  }

  /// Loads the stored key pair from secure storage.
  Future<SimpleKeyPair?> loadKeyPair() async {
    final privateKeyBase64 = await _secureStorage.read(
      key: _privateKeyStorageKey,
    );
    final publicKeyBase64 = await _secureStorage.read(
      key: _publicKeyStorageKey,
    );

    if (privateKeyBase64 == null || publicKeyBase64 == null) return null;

    return _cryptoService.importKeyPair(
      privateKeyBase64: privateKeyBase64,
      publicKeyBase64: publicKeyBase64,
    );
  }

  /// Returns the stored public key as base64.
  Future<String?> getPublicKey() async {
    return _secureStorage.read(key: _publicKeyStorageKey);
  }

  /// Deletes the key pair from secure storage (on logout).
  Future<void> deleteKeyPair() async {
    await _secureStorage.delete(key: _privateKeyStorageKey);
    await _secureStorage.delete(key: _publicKeyStorageKey);
  }
}
