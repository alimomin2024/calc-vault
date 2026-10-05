import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'core/vault.dart';
import 'ui/calculator_screen.dart';
import 'ui/design.dart';
import 'ui/setup.dart';
import 'ui/vault_screen.dart';
import 'ui/welcome_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalcVaultApp());
}

class CalcVaultApp extends StatefulWidget {
  final Vault? vault;
  const CalcVaultApp({super.key, this.vault});
  @override
  State<CalcVaultApp> createState() => _AppState();
}

class _AppState extends State<CalcVaultApp> with WidgetsBindingObserver {
  final navigator = GlobalKey<NavigatorState>();
  Vault? vault;
  String? error;
  bool obscured = false, capturing = false;
  StreamSubscription<AccelerometerEvent>? sensor;
  DateTime? faceDown;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize() async {
    try {
      final service = widget.vault ?? await Vault.create();
      if (!mounted) {
        service.dispose();
        return;
      }
      vault = service;
      service.addListener(changed);
      setState(() {});
      if (widget.vault == null) {
        sensor =
            accelerometerEventStream(
              samplingPeriod: const Duration(milliseconds: 100),
            ).listen(
              (event) {
                if (!service.unlocked || !service.panicEnabled) {
                  faceDown = null;
                  return;
                }
                if (event.z < -7.5) {
                  faceDown ??= DateTime.now();
                  if (DateTime.now().difference(faceDown!).inMilliseconds >=
                      200) {
                    service.lock();
                    faceDown = null;
                  }
                } else {
                  faceDown = null;
                }
              },
              onError: (Object _) {
                /* Sensors are optional on devices without hardware. */
              },
            );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = 'Unable to open secure storage. Restart the app.\n$e',
        );
      }
    }
  }

  void changed() {
    if (!mounted) {
      return;
    }
    if (vault?.unlocked != true) {
      navigator.currentState?.popUntil((route) => route.isFirst);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      obscured = true;
    } else {
      obscured = false;
    }
    if ([
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ].contains(state)) {
      vault?.lock();
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> capture() async {
    if (capturing || vault?.selfieEnabled != true || obscured) {
      return;
    }
    capturing = true;
    CameraController? controller;
    File? temporary;
    try {
      // Never requests permission from the calculator disguise.
      if (!await Permission.camera.isGranted) {
        return;
      }
      final cameras = await availableCameras();
      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (front.isEmpty || obscured) {
        return;
      }
      controller = CameraController(
        front.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      if (obscured) {
        return;
      }
      final photo = await controller.takePicture();
      temporary = File(photo.path);
      await vault!.saveIntruder(await temporary.readAsBytes());
    } catch (_) {
      /* A denied or unavailable camera never breaks calculator use. */
    } finally {
      await controller?.dispose();
      if (temporary != null && await temporary.exists()) {
        await temporary.delete();
      }
      capturing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sensor?.cancel();
    vault?.removeListener(changed);
    if (widget.vault == null) {
      vault?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    title: 'Calculator',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    builder: (context, child) => Stack(
      children: [
        child!,
        if (obscured)
          const Positioned.fill(
            child: ColoredBox(
              color: linen,
              child: Center(
                child: Icon(Icons.calculate_outlined, color: muted, size: 48),
              ),
            ),
          ),
      ],
    ),
    home: vault == null
        ? Scaffold(
            body: Center(
              child: error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(error!),
                    )
                  : const CircularProgressIndicator(),
            ),
          )
        : !vault!.configured && !vault!.welcomeSeen
        ? WelcomeScreen(
            vault: vault!,
            onContinue: () {
              if (mounted) setState(() {});
            },
          )
        : !vault!.configured
        ? SetupScreen(vault: vault!)
        : vault!.unlocked
        ? VaultScreen(vault: vault!)
        : CalculatorScreen(vault: vault!, capture: capture),
  );
}
