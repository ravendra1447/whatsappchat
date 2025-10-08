// lib/services/crypto_manager.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'dart:io';

/// A singleton class for handling encryption across the app.
class CryptoManager {
  static final CryptoManager _instance = CryptoManager._internal();

  factory CryptoManager() {
    return _instance;
  }

  CryptoManager._internal();

  // The 32-byte key (same as PHP, hex decoded). This must match the server.
  static final Uint8List _keyBytes = _hexToBytes(
    'b1b2b3b4b5b6b7b8b9babbbcbdbebff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff00',
  );

  final _algo = AesGcm.with256bits();
  late final SecretKey _secretKey;

  Future<void> init() async {
    _secretKey = SecretKey(_keyBytes);
  }

  /// 🔒 Encrypt and Gzip compress message data.
  Future<Map<String, dynamic>> encryptAndCompress(String message) async {
    final Map<String, dynamic> messageMap = {
      "type": "text",
      "content": message,
    };
    final inner = jsonEncode(messageMap);
    final gz = gzipEncode(utf8.encode(inner));

    final nonce = _algo.newNonce();
    final secretBox = await _algo.encrypt(
      gz,
      secretKey: _secretKey,
      nonce: nonce,
    );

    final encryptedData = {
      "nonce": base64Encode(nonce),
      "ciphertext": base64Encode(secretBox.cipherText),
      "tag": base64Encode(secretBox.mac.bytes),
    };

    return {
      'type': 'encrypted',
      'content': jsonEncode(encryptedData),
    };
  }

  /// 🔒 Encrypt and Gzip compress a byte array.
  Future<Map<String, dynamic>> encryptAndCompressBytes(Uint8List bytes) async {
    final compressedBytes = gzipEncode(bytes);
    final nonce = _algo.newNonce();
    final secretBox = await _algo.encrypt(
      compressedBytes,
      secretKey: _secretKey,
      nonce: nonce,
    );

    final encryptedData = {
      "nonce": base64Encode(nonce),
      "ciphertext": base64Encode(secretBox.cipherText),
      "tag": base64Encode(secretBox.mac.bytes),
    };

    return {
      'type': 'encrypted_media',
      'content': jsonEncode(encryptedData),
    };
  }

  /// 🔓 Decrypt and Gzip decompress message data.
  Future<Map<String, dynamic>> decryptAndDecompress(String encryptedString) async {
    try {
      final envelope = jsonDecode(encryptedString);
      final nonce = base64Decode(envelope['nonce']);
      final ciphertext = base64Decode(envelope['ciphertext']);
      final tag = base64Decode(envelope['tag']);

      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));
      final decrypted = await _algo.decrypt(secretBox, secretKey: _secretKey);

      final decompressed = gzipDecode(decrypted);
      final decodedJson = jsonDecode(utf8.decode(decompressed));

      return decodedJson as Map<String, dynamic>;
    } catch (e) {
      print("❌ Decrypt/Decompress failed: $e");
      if (e is FormatException) {
        return {"type": "text", "content": "[Decryption Failed: Bad Format]"};
      } else {
        return {"type": "text", "content": "[Decryption Failed: Corrupted Data]"};
      }
    }
  }

  /// 🔓 Decrypt and Gzip decompress a byte array.
  Future<Uint8List> decryptAndDecompressBytes(Uint8List encryptedBytes) async {
    try {
      final envelope = jsonDecode(utf8.decode(encryptedBytes));
      final nonce = base64Decode(envelope['nonce']);
      final ciphertext = base64Decode(envelope['ciphertext']);
      final tag = base64Decode(envelope['tag']);

      final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(tag));
      final decrypted = await _algo.decrypt(secretBox, secretKey: _secretKey);
      final decompressed = gzipDecode(decrypted);

      return Uint8List.fromList(decompressed);
    } catch (e) {
      print("❌ Decrypt/Decompress failed: $e");
      throw Exception("Decryption failed: $e");
    }
  }

  // gzip helpers
  List<int> gzipEncode(List<int> data) => GZipCodec(level: 6).encode(data);
  List<int> gzipDecode(List<int> data) => GZipCodec().decode(data);

  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw FormatException('Hex string must have an even length');
    }
    final result = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }
}