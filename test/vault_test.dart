import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calc_vault/core/vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Vault vault;
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('calcvault_test_');
    vault = Vault(
      storage: const FlutterSecureStorage(),
      root: Directory('${temp.path}/vault'),
      cache: Directory('${temp.path}/cache'),
    );
    await vault.root.create();
    await vault.cache.create();
    await vault.configure('8899', '1122');
  });
  tearDown(() async {
    vault.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });
  test(
    'Real and decoy domains remain isolated, encrypted and persistent',
    () async {
      expect(await vault.authenticate('8899'), isTrue);
      final bytes = Uint8List.fromList(utf8.encode('TOP SECRET CARD 1234'));
      final item = await vault.importBytes(
        bytes,
        name: 'Personal account',
        kind: 'record',
        folder: 'Personal',
      );
      final encrypted = await File(
        '${vault.domain.path}/${item.id}.cv',
      ).readAsBytes();
      expect(
        utf8.decode(encrypted, allowMalformed: true),
        isNot(contains('TOP SECRET')),
      );
      final manifest = await File(
        '${vault.domain.path}/index.cv',
      ).readAsBytes();
      expect(
        utf8.decode(manifest, allowMalformed: true),
        isNot(contains('Personal account')),
      );
      expect(await vault.read(item), orderedEquals(bytes));
      vault.lock();
      expect(await vault.authenticate('1122'), isTrue);
      expect(vault.decoy, isTrue);
      expect(vault.items, isEmpty);
      await vault.importBytes(
        Uint8List.fromList([1, 2, 3]),
        name: 'Harmless',
        kind: 'photo',
        folder: 'Personal',
      );
      vault.lock();
      expect(await vault.authenticate('8899'), isTrue);
      expect(vault.items.single.name, 'Personal account');
      expect(await vault.read(vault.items.single), orderedEquals(bytes));
    },
  );
  test(
    'Three incorrect attempts persist a cooldown, successful login resets it',
    () async {
      for (var i = 0; i < 3; i++) {
        expect(await vault.authenticate('9988'), isFalse);
      }
      expect(vault.failures, 3);
      expect(vault.remainingCooldown, greaterThan(0));
      expect(await vault.authenticate('8899'), isFalse);
      final config = await vault.storage.read(key: 'calcvault_config_v1');
      expect(jsonDecode(config!)['failures'], 3);
    },
  );
  test(
    'Lock rejects reads and writes; damaged manifest fails closed',
    () async {
      expect(await vault.authenticate('8899'), isTrue);
      final item = await vault.importBytes(
        Uint8List.fromList([10, 20]),
        name: 'Private',
        kind: 'photo',
        folder: 'Personal',
      );
      final directory = vault.domain;
      vault.lock();
      expect(vault.items, isEmpty);
      await expectLater(vault.read(item), throwsStateError);
      await expectLater(
        vault.importBytes(
          Uint8List(3),
          name: 'x',
          kind: 'photo',
          folder: 'Personal',
        ),
        throwsStateError,
      );
      await File('${directory.path}/index.cv').writeAsBytes([1, 2, 3]);
      await expectLater(vault.authenticate('8899'), throwsFormatException);
      expect(vault.unlocked, isFalse);
      expect(vault.items, isEmpty);
    },
  );
  test('Folder moves and deletes persist in encrypted manifest', () async {
    await vault.authenticate('8899');
    final item = await vault.importBytes(
      Uint8List.fromList([1]),
      name: 'Private',
      kind: 'photo',
      folder: 'Personal',
    );
    await expectLater(vault.addFolder('All folders'), throwsFormatException);
    await vault.addFolder('Trips');
    await vault.move(item, 'Trips');
    vault.lock();
    await vault.authenticate('8899');
    expect(vault.items.single.folder, 'Trips');
    expect(vault.folders, contains('Trips'));
    await vault.delete(vault.items.single);
    vault.lock();
    await vault.authenticate('8899');
    expect(vault.items, isEmpty);
  });
}
