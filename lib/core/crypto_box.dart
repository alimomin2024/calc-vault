import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

class CryptoBox {
  static Uint8List randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(length, (_) => random.nextInt(256)),
    );
  }

  // Version | 96-bit random nonce | AES-GCM ciphertext and 128-bit tag.
  static Uint8List seal(
    Uint8List bytes,
    Uint8List key, {
    String context = 'CalcVault/v1',
  }) {
    final nonce = randomBytes(12);
    final cipher = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    final encrypted = cipher.encryptBytes(
      bytes,
      iv: enc.IV(nonce),
      associatedData: Uint8List.fromList(utf8.encode(context)),
    );
    final output = Uint8List(13 + encrypted.bytes.length);
    output[0] = 1;
    output.setRange(1, 13, nonce);
    output.setRange(13, output.length, encrypted.bytes);
    return output;
  }

  static Uint8List open(
    Uint8List bytes,
    Uint8List key, {
    String context = 'CalcVault/v1',
  }) {
    if (bytes.length < 29 || bytes[0] != 1) {
      throw const FormatException('Invalid encrypted file');
    }
    final cipher = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    return Uint8List.fromList(
      cipher.decryptBytes(
        enc.Encrypted(Uint8List.sublistView(bytes, 13)),
        iv: enc.IV(bytes.sublist(1, 13)),
        associatedData: Uint8List.fromList(utf8.encode(context)),
      ),
    );
  }

  static Uint8List pinHash(String pin, Uint8List salt) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 120000, 32));
    return kdf.process(Uint8List.fromList(utf8.encode(pin)));
  }

  static bool equal(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }
}
