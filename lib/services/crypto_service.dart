import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class CryptoService {
  static Future<bool> verifySignature(
    String payloadJson,
    List<int> signatureBytes,
    String publicKeyPem,
  ) async {
    try {
      // 1. Clean the PEM string to get raw base64
      final cleanedPem = publicKeyPem
          .replaceAll('-----BEGIN PUBLIC KEY-----', '')
          .replaceAll('-----END PUBLIC KEY-----', '')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .trim();

      // 2. Decode base64
      final keyBytes = base64Decode(cleanedPem);
      if (keyBytes.length < 32) return false;
      
      // 3. Extract the actual 32-byte Ed25519 public key
      final publicKeyBytes = keyBytes.sublist(keyBytes.length - 32);

      // 4. Verify using the modern cryptography package
      final algorithm = Ed25519();
      final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
      
      final isValid = await algorithm.verify(
        utf8.encode(payloadJson),
        signature: Signature(signatureBytes, publicKey: publicKey),
      );
      
      return isValid;
    } catch (e) {
      print('Crypto verification failed: \$e');
      return false;
    }
  }
}
