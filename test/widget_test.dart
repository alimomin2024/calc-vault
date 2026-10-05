import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calc_vault/main.dart';
import 'package:calc_vault/core/vault.dart';
import 'package:calc_vault/ui/calculator_screen.dart';
import 'package:calc_vault/ui/design.dart';
import 'package:calc_vault/ui/setup.dart';
import 'package:calc_vault/ui/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late Vault vault;
  setUpAll(() async {
    for (final name in ['PlayfairDisplay', 'PlusJakartaSans']) {
      final loader = FontLoader(name)
        ..addFont(rootBundle.load('assets/fonts/$name.ttf'));
      await loader.load();
    }
  });
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    temp = await Directory.systemTemp.createTemp('calcvault_widget_');
    vault = Vault(
      storage: const FlutterSecureStorage(),
      root: Directory('${temp.path}/vault'),
      cache: Directory('${temp.path}/cache'),
    );
    await vault.root.create();
    await vault.cache.create();
  });
  tearDown(() async {
    vault.dispose();
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });
  testWidgets('Setup fits compact phone and scrolls to creation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: SetupScreen(vault: vault),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('A little privacy.\nA lot of peace.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Create my private space'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Calculator computes and scientific functions are available', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: CalculatorScreen(vault: vault, capture: () async {}),
      ),
    );
    for (final key in ['2', '+', '3', '=']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }
    expect(find.text('5'), findsNWidgets(2));
    await tester.tap(find.text('±'));
    await tester.pump();
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('-5'), findsOneWidget);
    await tester.tap(find.text('Scientific functions'));
    await tester.pumpAndSettle();
    expect(find.text('sin'), findsOneWidget);
    expect(find.text('√'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Vault fits narrow device and offers working import menu', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await vault.configure('8899', '1122');
      await vault.authenticate('8899');
    });
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: VaultScreen(vault: vault),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to vault'));
    await tester.pumpAndSettle();
    expect(find.text('Photos & videos'), findsOneWidget);
    expect(find.text('Password or card'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'PIN followed by equals opens vault and background locks all routes',
    (tester) async {
      await tester.runAsync(() => vault.configure('8899', '1122'));
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(CalcVaultApp(vault: vault));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final key in ['8', '8', '9', '9', '=']) {
          await tester.tap(find.text(key));
        }
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!vault.unlocked && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Only for your eyes.'), findsOneWidget);
      await tester.tap(find.byTooltip('Security'));
      await tester.pumpAndSettle();
      expect(find.text('Peace of mind'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(vault.unlocked, isFalse);
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Peace of mind'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
