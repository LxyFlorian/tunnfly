import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Handles all E2E encryption logic.
///
/// Key exchange: X25519 (Diffie-Hellman)
/// Message encryption: AES-256-GCM
class CryptoService {
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();

  /// Generates a new X25519 key pair for the user.
  Future<SimpleKeyPair> generateKeyPair() async {
    return await _x25519.newKeyPair();
  }

  /// Exports a public key as a base64 string for storage in Supabase.
  Future<String> exportPublicKey(SimpleKeyPair keyPair) async {
    final publicKey = await keyPair.extractPublicKey();
    return base64Encode(publicKey.bytes);
  }

  /// Exports a private key as a base64 string for local secure storage.
  Future<String> exportPrivateKey(SimpleKeyPair keyPair) async {
    final extracted = await keyPair.extract();
    final privateKeyBytes = extracted.bytes;
    return base64Encode(privateKeyBytes);
  }

  /// Imports a key pair from stored base64 strings.
  Future<SimpleKeyPair> importKeyPair({
    required String privateKeyBase64,
    required String publicKeyBase64,
  }) async {
    final privateKeyBytes = base64Decode(privateKeyBase64);
    final publicKeyBytes = base64Decode(publicKeyBase64);

    return SimpleKeyPairData(
      privateKeyBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
  }

  /// Derives a shared secret from our private key and the other user's public key.
  Future<Uint8List> deriveSharedSecret({
    required SimpleKeyPair ourKeyPair,
    required String theirPublicKeyBase64,
  }) async {
    final theirPublicKeyBytes = base64Decode(theirPublicKeyBase64);
    final theirPublicKey = SimplePublicKey(
      theirPublicKeyBytes,
      type: KeyPairType.x25519,
    );

    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: ourKeyPair,
      remotePublicKey: theirPublicKey,
    );

    final secretBytes = await sharedSecret.extractBytes();
    return Uint8List.fromList(secretBytes);
  }

  /// Encrypts a plaintext message using AES-256-GCM.
  /// Returns a map with 'ciphertext' and 'iv' as base64 strings.
  Future<({String ciphertext, String iv})> encryptMessage({
    required String plaintext,
    required Uint8List sharedSecret,
  }) async {
    final secretKey = SecretKey(sharedSecret);
    final nonce = _aesGcm.newNonce();
    final plaintextBytes = utf8.encode(plaintext);

    final secretBox = await _aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final ciphertext = base64Encode(
      Uint8List.fromList([...secretBox.cipherText, ...secretBox.mac.bytes]),
    );
    final iv = base64Encode(Uint8List.fromList(nonce));

    return (ciphertext: ciphertext, iv: iv);
  }

  /// Decrypts a ciphertext using AES-256-GCM.
  /// Returns null if decryption fails (tampered message).
  Future<String?> decryptMessage({
    required String ciphertextBase64,
    required String ivBase64,
    required Uint8List sharedSecret,
  }) async {
    try {
      final secretKey = SecretKey(sharedSecret);
      final nonce = base64Decode(ivBase64);
      final combined = base64Decode(ciphertextBase64);

      // Last 16 bytes are the GCM authentication tag
      const macLength = 16;
      final cipherText = combined.sublist(0, combined.length - macLength);
      final macBytes = combined.sublist(combined.length - macLength);

      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );

      final decrypted = await _aesGcm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      return utf8.decode(decrypted);
    } catch (_) {
      return null;
    }
  }
}
