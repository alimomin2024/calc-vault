import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:calc_vault/core/crypto_box.dart';

void main() {
  test('AES-256 GCM round trip, unique nonce and tamper detection', () {
    final key = CryptoBox.randomBytes(32);
    final plaintext = Uint8List.fromList(
      utf8.encode('private media and secrets'),
    );
    final a = CryptoBox.seal(plaintext, key, context: 'item/a');
    final b = CryptoBox.seal(plaintext, key, context: 'item/a');
    expect(a, isNot(orderedEquals(b)));
    expect(CryptoBox.open(a, key, context: 'item/a'), orderedEquals(plaintext));
    final tampered = Uint8List.fromList(a)..[15] ^= 1;
    expect(
      () => CryptoBox.open(tampered, key, context: 'item/a'),
      throwsA(anything),
    );
    expect(() => CryptoBox.open(a, key, context: 'item/b'), throwsA(anything));
    expect(
      () => CryptoBox.open(a, CryptoBox.randomBytes(32), context: 'item/a'),
      throwsA(anything),
    );
    expect(() => CryptoBox.open(Uint8List(4), key), throwsFormatException);
  });
  test('Empty and arbitrary binary data authenticate', () {
    final key = CryptoBox.randomBytes(32);
    for (final data in [
      Uint8List(0),
      Uint8List.fromList(List.generate(513, (i) => i % 256)),
    ]) {
      expect(
        CryptoBox.open(CryptoBox.seal(data, key), key),
        orderedEquals(data),
      );
    }
  });
  test('PIN derivation is salted and comparisons reject mismatch', () {
    final salt = CryptoBox.randomBytes(32);
    final hash = CryptoBox.pinHash('8899', salt);
    expect(CryptoBox.equal(hash, CryptoBox.pinHash('8899', salt)), isTrue);
    expect(CryptoBox.equal(hash, CryptoBox.pinHash('8898', salt)), isFalse);
    expect(
      CryptoBox.equal(
        hash,
        CryptoBox.pinHash('8899', CryptoBox.randomBytes(32)),
      ),
      isFalse,
    );
  });
}
