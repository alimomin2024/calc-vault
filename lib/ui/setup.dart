import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/vault.dart';
import 'design.dart';

class SetupScreen extends StatefulWidget {
  final Vault vault;
  const SetupScreen({super.key, required this.vault});
  @override
  State<SetupScreen> createState() => _SetupState();
}

class _SetupState extends State<SetupScreen> {
  final master = TextEditingController(),
      confirm = TextEditingController(),
      decoy = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    master.dispose();
    confirm.dispose();
    decoy.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (master.text != confirm.text) {
      message(context, 'Master PINs do not match.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.vault.configure(master.text, decoy.text);
    } catch (e) {
      if (mounted) {
        message(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget field(TextEditingController controller, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 12,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: title, counterText: ''),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(28),
            children: [
              const Row(
                children: [
                  Icon(Icons.calculate_outlined, size: 32),
                  SizedBox(width: 10),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'CALCVAULT',
                        style: TextStyle(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Tag('OFFLINE'),
                ],
              ),
              const SizedBox(height: 42),
              Text('A little privacy.\nA lot of peace.', style: editorial(40)),
              const SizedBox(height: 14),
              const Text(
                'Your everyday calculator. Your private space.\nEverything stays on this device.',
                style: TextStyle(color: muted, height: 1.7),
              ),
              const SizedBox(height: 28),
              const PaperCard(
                color: ink,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: khaki, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'AES-256 encryption\nNo accounts. No cloud. No internet.',
                        style: TextStyle(color: Colors.white, height: 1.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Make it yours', style: editorial(25)),
              const SizedBox(height: 14),
              field(master, 'Master PIN · 4–12 digits'),
              field(confirm, 'Confirm master PIN'),
              field(decoy, 'Different decoy PIN · 4–12 digits'),
              const Text(
                'Enter your PIN, then = to open your vault. The secondary PIN opens a separate empty vault. Choose a long PIN: there is no recovery if you forget it or uninstall the app.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.7),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(
                  busy ? 'Securing your space…' : 'Create my private space',
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Camera and microphone access are optional.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
