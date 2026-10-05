import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'crypto_box.dart';

const _mediaWorkerThreshold = 256 * 1024;

Uint8List _sealMedia(List<dynamic> args) {
  final plaintext = (args[0] as TransferableTypedData)
      .materialize()
      .asUint8List();
  final key = args[1] as Uint8List;
  try {
    return CryptoBox.seal(plaintext, key, context: args[2] as String);
  } finally {
    plaintext.fillRange(0, plaintext.length, 0);
    key.fillRange(0, key.length, 0);
  }
}

Uint8List _openMedia(List<dynamic> args) {
  final ciphertext = (args[0] as TransferableTypedData)
      .materialize()
      .asUint8List();
  final key = args[1] as Uint8List;
  try {
    return CryptoBox.open(ciphertext, key, context: args[2] as String);
  } finally {
    ciphertext.fillRange(0, ciphertext.length, 0);
    key.fillRange(0, key.length, 0);
  }
}

class VaultItem {
  final String id, name, kind, folder, extension;
  final int size;
  final DateTime created;
  const VaultItem({
    required this.id,
    required this.name,
    required this.kind,
    required this.folder,
    required this.extension,
    required this.size,
    required this.created,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    'folder': folder,
    'extension': extension,
    'size': size,
    'created': created.toIso8601String(),
  };
  factory VaultItem.fromJson(Map<String, dynamic> j) => VaultItem(
    id: j['id'],
    name: j['name'],
    kind: j['kind'],
    folder: j['folder'],
    extension: j['extension'],
    size: j['size'],
    created: DateTime.parse(j['created']),
  );
}

class Vault extends ChangeNotifier {
  final FlutterSecureStorage storage;
  final Directory root, cache;
  Map<String, dynamic>? _config;
  Uint8List? _key;
  bool ready = false, unlocked = false, decoy = false, welcomeSeen = false;
  int session = 0;
  List<VaultItem> items = [];
  List<String> folders = ['Personal', 'Documents', 'Audio notes'];
  Future<void> _writes = Future.value();
  Future<void> _cacheWrites = Future.value();
  Future<void> galleryCacheCleanup = Future.value();
  Vault({required this.storage, required this.root, required this.cache});
  static Future<Vault> create() async {
    final documents = await getApplicationSupportDirectory();
    final temp = await getTemporaryDirectory();
    final vault = Vault(
      storage: const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.unlocked_this_device,
        ),
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
      root: Directory('${documents.path}/vault'),
      cache: Directory('${temp.path}/calcvault_preview'),
    );
    await vault.root.create(recursive: true);
    await vault.purgeCache(clearGalleryCache: false);
    vault.galleryCacheCleanup = PhotoManager.clearFileCache().catchError(
      (Object _) {},
    );
    final saved = await vault.storage.read(key: 'calcvault_config_v1');
    if (saved != null) {
      vault._config = jsonDecode(saved);
      vault.welcomeSeen = true;
    } else {
      vault.welcomeSeen =
          await vault.storage.read(key: 'calcvault_welcome_v1') == 'true';
    }
    vault.ready = true;
    return vault;
  }

  bool get configured => _config != null;
  Future<void> markWelcomeSeen() async {
    welcomeSeen = true;
    await storage.write(key: 'calcvault_welcome_v1', value: 'true');
  }

  bool get selfieEnabled => _config?['selfie'] == true;
  bool get panicEnabled => _config?['panic'] != false;
  int get failures => (_config?['failures'] as int?) ?? 0;
  int get remainingCooldown =>
      (((_config?['retryAt'] as int?) ?? 0) -
          DateTime.now().millisecondsSinceEpoch) ~/
      1000;
  bool pinCandidate(String value) =>
      RegExp(r'^\d{4,12}$').hasMatch(value) &&
      (value.length == _config?['masterLength'] ||
          value.length == _config?['decoyLength']);
  Directory get domain =>
      Directory('${root.path}/${decoy ? 'secondary' : 'primary'}');
  Future<void> _saveConfig() =>
      storage.write(key: 'calcvault_config_v1', value: jsonEncode(_config));
  Future<void> configure(String master, String alternate) async {
    if (configured) {
      throw StateError('Already configured');
    }
    if (!RegExp(r'^\d{4,12}$').hasMatch(master) ||
        !RegExp(r'^\d{4,12}$').hasMatch(alternate) ||
        master == alternate) {
      throw const FormatException('Use two different PINs with 4–12 digits.');
    }
    final salt = CryptoBox.randomBytes(32);
    final secondSalt = CryptoBox.randomBytes(32);
    final hashes = await Future.wait([
      compute((List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]), [
        master,
        salt,
      ]),
      compute((List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]), [
        alternate,
        secondSalt,
      ]),
    ]);
    _config = {
      'masterSalt': base64Encode(salt),
      'decoySalt': base64Encode(secondSalt),
      'masterHash': base64Encode(sha256.convert(hashes[0]).bytes),
      'decoyHash': base64Encode(sha256.convert(hashes[1]).bytes),
      'masterLength': master.length,
      'decoyLength': alternate.length,
      'primaryKey': base64Encode(
        CryptoBox.seal(
          CryptoBox.randomBytes(32),
          hashes[0],
          context: 'key/primary',
        ),
      ),
      'secondaryKey': base64Encode(
        CryptoBox.seal(
          CryptoBox.randomBytes(32),
          hashes[1],
          context: 'key/secondary',
        ),
      ),
      'failures': 0,
      'retryAt': 0,
      'selfie': false,
      'panic': true,
    };
    for (final hash in hashes) {
      hash.fillRange(0, hash.length, 0);
    }
    await storage.write(
      key: 'calcvault_evidence_key',
      value: base64Encode(CryptoBox.randomBytes(32)),
    );
    await _saveConfig();
    notifyListeners();
  }

  Future<void> changeCurrentPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!RegExp(r'^\d{4,12}$').hasMatch(newPin)) {
      throw const FormatException('Choose a PIN with 4–12 digits.');
    }
    if (currentPin == newPin) {
      throw const FormatException('Choose a different PIN.');
    }
    final generation = session;
    _check(generation);
    final activePrefix = decoy ? 'decoy' : 'master';
    final otherPrefix = decoy ? 'master' : 'decoy';
    final saltKey = '${activePrefix}Salt';
    final hashKey = '${activePrefix}Hash';
    final lengthKey = '${activePrefix}Length';
    final otherSaltKey = '${otherPrefix}Salt';
    final otherHashKey = '${otherPrefix}Hash';
    final wrappedKey = decoy ? 'secondaryKey' : 'primaryKey';
    final context = decoy ? 'key/secondary' : 'key/primary';
    final oldSalt = base64Decode(_config![saltKey]);
    Uint8List? oldDerived;
    Uint8List? nextDerived;
    Uint8List? otherDerived;
    Uint8List? contentKey;
    try {
      final oldKey = await compute(
        (List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]),
        [currentPin, oldSalt],
      );
      oldDerived = oldKey;
      _check(generation);
      if (!CryptoBox.equal(
        sha256.convert(oldKey).bytes,
        base64Decode(_config![hashKey]),
      )) {
        throw const FormatException('Current PIN is incorrect.');
      }

      final otherSalt = base64Decode(_config![otherSaltKey]);
      final alternateKey = await compute(
        (List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]),
        [newPin, otherSalt],
      );
      otherDerived = alternateKey;
      _check(generation);
      if (CryptoBox.equal(
        sha256.convert(alternateKey).bytes,
        base64Decode(_config![otherHashKey]),
      )) {
        throw const FormatException(
          'The new PIN must differ from the other PIN.',
        );
      }

      final nextSalt = CryptoBox.randomBytes(32);
      final newKey = await compute(
        (List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]),
        [newPin, nextSalt],
      );
      nextDerived = newKey;
      _check(generation);
      final unwrappedKey = CryptoBox.open(
        base64Decode(_config![wrappedKey]),
        oldKey,
        context: context,
      );
      contentKey = unwrappedKey;
      final oldValues = <String, dynamic>{
        saltKey: _config![saltKey],
        hashKey: _config![hashKey],
        wrappedKey: _config![wrappedKey],
        lengthKey: _config![lengthKey],
      };
      _config![saltKey] = base64Encode(nextSalt);
      _config![hashKey] = base64Encode(sha256.convert(newKey).bytes);
      _config![wrappedKey] = base64Encode(
        CryptoBox.seal(unwrappedKey, newKey, context: context),
      );
      _config![lengthKey] = newPin.length;
      try {
        await _saveConfig();
        _check(generation);
      } catch (_) {
        _config!.addAll(oldValues);
        rethrow;
      }
      notifyListeners();
    } finally {
      oldSalt.fillRange(0, oldSalt.length, 0);
      oldDerived?.fillRange(0, oldDerived.length, 0);
      nextDerived?.fillRange(0, nextDerived.length, 0);
      otherDerived?.fillRange(0, otherDerived.length, 0);
      contentKey?.fillRange(0, contentKey.length, 0);
    }
  }

  Future<bool> authenticate(String pin) async {
    if (!configured || unlocked || remainingCooldown > 0) {
      return false;
    }
    final config = _config!;
    final generation = session;
    final hashes = await Future.wait([
      compute((List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]), [
        pin,
        base64Decode(config['masterSalt']),
      ]),
      compute((List<dynamic> p) => CryptoBox.pinHash(p[0], p[1]), [
        pin,
        base64Decode(config['decoySalt']),
      ]),
    ]);
    if (generation != session) {
      for (final hash in hashes) {
        hash.fillRange(0, hash.length, 0);
      }
      return false;
    }
    final real = CryptoBox.equal(
      sha256.convert(hashes[0]).bytes,
      base64Decode(config['masterHash']),
    );
    final secondary = CryptoBox.equal(
      sha256.convert(hashes[1]).bytes,
      base64Decode(config['decoyHash']),
    );
    if (!real && !secondary) {
      for (final hash in hashes) {
        hash.fillRange(0, hash.length, 0);
      }
      config['failures'] = failures + 1;
      if (failures >= 3) {
        config['retryAt'] =
            DateTime.now().millisecondsSinceEpoch +
            30000 * (failures ~/ 3).clamp(1, 10);
      }
      await _saveConfig();
      return false;
    }
    decoy = !real;
    try {
      _key = CryptoBox.open(
        base64Decode(config[decoy ? 'secondaryKey' : 'primaryKey']),
        hashes[decoy ? 1 : 0],
        context: 'key/${decoy ? 'secondary' : 'primary'}',
      );
      for (final hash in hashes) {
        hash.fillRange(0, hash.length, 0);
      }
      await domain.create(recursive: true);
      final manifest = File('${domain.path}/index.cv');
      if (await manifest.exists()) {
        final data = jsonDecode(
          utf8.decode(
            CryptoBox.open(
              await manifest.readAsBytes(),
              _key!,
              context: 'index/${decoy ? 'secondary' : 'primary'}',
            ),
          ),
        );
        items = (data['items'] as List)
            .map((j) => VaultItem.fromJson(Map<String, dynamic>.from(j)))
            .toList();
        folders = List<String>.from(data['folders']);
      } else {
        items = [];
        folders = ['Personal', 'Documents', 'Audio notes'];
      }
      if (generation != session) {
        _clear();
        return false;
      }
      config['failures'] = 0;
      config['retryAt'] = 0;
      await _saveConfig();
      if (generation != session) {
        _clear();
        return false;
      }
      unlocked = true;
      notifyListeners();
      return true;
    } catch (_) {
      _clear();
      rethrow;
    }
  }

  void _clear() {
    _key?.fillRange(0, _key!.length, 0);
    _key = null;
    items = [];
    folders = ['Personal', 'Documents', 'Audio notes'];
    unlocked = false;
  }

  void lock() {
    session++;
    _clear();
    notifyListeners();
    // Operations in flight check session before exposing or committing data.
    unawaited(_writes.then((_) => purgeCache()));
  }

  Future<void> purgeCache({bool clearGalleryCache = true}) {
    final next = _cacheWrites.then(
      (_) => _purgeCache(clearGalleryCache: clearGalleryCache),
    );
    _cacheWrites = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return next;
  }

  Future<void> _purgeCache({required bool clearGalleryCache}) async {
    if (await cache.exists()) {
      await cache.delete(recursive: true);
    }
    await cache.create(recursive: true);
    if (clearGalleryCache) {
      try {
        await PhotoManager.clearFileCache();
      } catch (_) {}
    }
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _check(int generation) {
    if (!unlocked || _key == null || generation != session) {
      throw StateError('Vault locked. Unlock and try again.');
    }
  }

  Future<void> _manifest(int generation) async {
    _check(generation);
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'items': items.map((i) => i.toJson()).toList(),
          'folders': folders,
        }),
      ),
    );
    final encrypted = CryptoBox.seal(
      bytes,
      _key!,
      context: 'index/${decoy ? 'secondary' : 'primary'}',
    );
    final target = File('${domain.path}/index.cv');
    final staging = File('${target.path}.pending');
    await staging.writeAsBytes(encrypted, flush: true);
    _check(generation);
    await staging.rename(target.path);
  }

  Future<VaultItem> importBytes(
    Uint8List bytes, {
    required String name,
    required String kind,
    required String folder,
    String extension = 'bin',
  }) {
    final generation = session;
    return _serial(() async {
      _check(generation);
      if (bytes.length > 150 * 1024 * 1024) {
        throw const FormatException('Maximum file size is 150 MB.');
      }
      final id = base64UrlEncode(CryptoBox.randomBytes(18));
      final item = VaultItem(
        id: id,
        name: name,
        kind: kind,
        folder: folder,
        extension: extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
        size: bytes.length,
        created: DateTime.now(),
      );
      final key = Uint8List.fromList(_key!);
      late final Uint8List encrypted;
      try {
        if (bytes.length <= _mediaWorkerThreshold) {
          encrypted = CryptoBox.seal(bytes, key, context: 'item/$id');
        } else {
          encrypted = await compute(_sealMedia, [
            TransferableTypedData.fromList([bytes]),
            key,
            'item/$id',
          ]);
        }
      } finally {
        key.fillRange(0, key.length, 0);
      }
      _check(generation);
      final file = File('${domain.path}/$id.cv');
      try {
        await file.writeAsBytes(encrypted, flush: true);
      } finally {
        encrypted.fillRange(0, encrypted.length, 0);
      }
      _check(generation);
      items = [...items, item];
      try {
        await _manifest(generation);
      } catch (_) {
        items = items.where((i) => i.id != id).toList();
        rethrow;
      }
      _check(generation);
      notifyListeners();
      return item;
    });
  }

  Future<Uint8List> read(VaultItem item) async {
    final generation = session;
    _check(generation);
    final encrypted = await File('${domain.path}/${item.id}.cv').readAsBytes();
    _check(generation);
    final key = Uint8List.fromList(_key!);
    try {
      final bytes = encrypted.length <= _mediaWorkerThreshold
          ? CryptoBox.open(encrypted, key, context: 'item/${item.id}')
          : await compute(_openMedia, [
              TransferableTypedData.fromList([encrypted]),
              key,
              'item/${item.id}',
            ]);
      _check(generation);
      return bytes;
    } finally {
      key.fillRange(0, key.length, 0);
      encrypted.fillRange(0, encrypted.length, 0);
    }
  }

  Future<File> preview(VaultItem item) async {
    final generation = session;
    final bytes = await read(item);
    final file = File('${cache.path}/${item.id}.${item.extension}');
    try {
      _check(generation);
      await file.writeAsBytes(bytes, flush: true);
      if (!unlocked || generation != session) {
        if (await file.exists()) {
          await file.delete();
        }
        throw StateError('Vault locked');
      }
      return file;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  Future<void> addFolder(String name) {
    final generation = session;
    return _serial(() async {
      _check(generation);
      name = name.trim();
      if (name == 'All folders') {
        throw const FormatException('Choose a different collection name.');
      }
      if (name.isEmpty || folders.contains(name)) {
        return;
      }
      folders = [...folders, name];
      await _manifest(generation);
      notifyListeners();
    });
  }

  Future<void> move(VaultItem item, String folder) {
    final generation = session;
    return _serial(() async {
      _check(generation);
      items = items
          .map(
            (i) => i.id == item.id
                ? VaultItem(
                    id: i.id,
                    name: i.name,
                    kind: i.kind,
                    folder: folder,
                    extension: i.extension,
                    size: i.size,
                    created: i.created,
                  )
                : i,
          )
          .toList();
      await _manifest(generation);
      notifyListeners();
    });
  }

  Future<void> delete(VaultItem item) {
    final generation = session;
    return _serial(() async {
      _check(generation);
      final original = items;
      items = items.where((i) => i.id != item.id).toList();
      try {
        await _manifest(generation);
      } catch (_) {
        items = original;
        rethrow;
      }
      await File('${domain.path}/${item.id}.cv').delete();
      notifyListeners();
    });
  }

  Future<void> setSecurity({bool? selfie, bool? panic}) async {
    if (!unlocked || decoy) {
      return;
    }
    if (selfie != null) {
      _config!['selfie'] = selfie;
    }
    if (panic != null) {
      _config!['panic'] = panic;
    }
    await _saveConfig();
    notifyListeners();
  }

  Future<void> saveIntruder(Uint8List photo) async {
    if (!configured) {
      return;
    }
    // Separate evidence store; never unlocks or reads private media.
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final directory = Directory('${root.path}/evidence');
    await directory.create(recursive: true);
    final savedKey = await storage.read(key: 'calcvault_evidence_key');
    if (savedKey == null) {
      return;
    }
    final key = base64Decode(savedKey);
    await File('${directory.path}/$id.cv').writeAsBytes(
      CryptoBox.seal(photo, key, context: 'evidence/$id'),
      flush: true,
    );
    key.fillRange(0, key.length, 0);
  }

  Future<List<(DateTime, Uint8List)>> evidence() async {
    if (!unlocked || decoy) {
      return [];
    }
    final generation = session;
    final directory = Directory('${root.path}/evidence');
    if (!await directory.exists()) {
      return [];
    }
    final savedKey = await storage.read(key: 'calcvault_evidence_key');
    _check(generation);
    if (savedKey == null) {
      return [];
    }
    final evidenceKey = base64Decode(savedKey);
    final result = <(DateTime, Uint8List)>[];
    await for (final file in directory.list()) {
      _check(generation);
      if (file is! File || !file.path.endsWith('.cv')) {
        continue;
      }
      final id = file.uri.pathSegments.last.split('.').first;
      final encrypted = await file.readAsBytes();
      _check(generation);
      result.add((
        DateTime.fromMillisecondsSinceEpoch(int.parse(id)),
        CryptoBox.open(encrypted, evidenceKey, context: 'evidence/$id'),
      ));
    }
    evidenceKey.fillRange(0, evidenceKey.length, 0);
    result.sort((a, b) => b.$1.compareTo(a.$1));
    return result;
  }
}
