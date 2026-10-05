import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calc_vault/core/vault.dart';
import 'package:calc_vault/ui/design.dart';
import 'package:calc_vault/ui/setup.dart';
import 'package:calc_vault/ui/calculator_screen.dart';
import 'package:calc_vault/ui/vault_screen.dart';
import 'package:calc_vault/ui/security_screen.dart';
import 'package:calc_vault/ui/record_editor.dart';
import 'package:calc_vault/ui/viewer.dart';

void main() {
  testWidgets('Render local app previews using sample data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late Vault vault;
    late Directory temp;
    await tester.runAsync(() async {
      for (final name in ['PlayfairDisplay', 'PlusJakartaSans']) {
        await (FontLoader(
          name,
        )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader(
        'Ahem',
      )..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'))).load();
      // This script runs through flutter test with isolated sample storage.
      // ignore: invalid_use_of_visible_for_testing_member
      FlutterSecureStorage.setMockInitialValues({});
      temp = await Directory.systemTemp.createTemp('calcvault_preview_');
      vault = Vault(
        storage: const FlutterSecureStorage(),
        root: Directory('${temp.path}/vault'),
        cache: Directory('${temp.path}/cache'),
      );
      await vault.root.create();
      await vault.cache.create();
    });
    final boundary = GlobalKey();
    Future<void> screenshot(String name, Widget screen) async {
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            home: screen,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      for (var frame = 0; frame < 3; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      final renderedImages = find.byType(Image).evaluate().toList();
      await tester.runAsync(() async {
        for (final element in renderedImages) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pump();
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final outDir = Directory('store_assets/raw_screenshots');
        if (!outDir.existsSync()) {
          outDir.createSync(recursive: true);
        }
        await File('${outDir.path}/$name.png').writeAsBytes(data!.buffer.asUint8List());
        try {
          await File(
            '/Users/alimomin/Documents/Codex/2026-10-02/xr/outputs/$name.png',
          ).writeAsBytes(data.buffer.asUint8List());
        } catch (_) {}
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }

    await screenshot('05_stealth_setup', SetupScreen(vault: vault));
    await tester.runAsync(() => vault.configure('8899', '1122'));
    await screenshot(
      '01_calculator_disguise',
      CalculatorScreen(vault: vault, capture: () async {}),
    );
    await tester.runAsync(() async {
      await vault.authenticate('8899');
      for (final asset in ['afternoon', 'coast']) {
        final data = await rootBundle.load('assets/decoy/$asset.png');
        await vault.importBytes(
          data.buffer.asUint8List(),
          name: asset == 'coast' ? 'Weekend by the sea' : 'A quiet afternoon',
          kind: 'photo',
          folder: 'Personal',
          extension: 'png',
        );
      }
    });
    await screenshot('02_secure_vault', VaultScreen(vault: vault));
    await screenshot('04_security_center', SecurityScreen(vault: vault));
    await screenshot('06_encrypted_passwords', RecordEditor(vault: vault, folder: 'Personal'));

    await tester.runAsync(() async {
      await vault.authenticate('1122');
    });
    await screenshot('03_decoy_vault', VaultScreen(vault: vault));

    await tester.pumpWidget(const SizedBox());
    vault.dispose();
    await tester.runAsync(() => temp.delete(recursive: true));
  });
}
