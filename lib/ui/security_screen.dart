import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/vault.dart';
import 'design.dart';

class SecurityScreen extends StatelessWidget {
  final Vault vault;
  const SecurityScreen({super.key, required this.vault});
  Future<void> _changePin(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Change ${vault.decoy ? 'decoy' : 'main'} PIN',
          style: editorial(24),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _pinField(current, 'Current PIN'),
              const SizedBox(height: 10),
              _pinField(next, 'New PIN · 4–12 digits'),
              const SizedBox(height: 10),
              _pinField(confirm, 'Confirm new PIN'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, [
              current.text,
              next.text,
              confirm.text,
            ]),
            child: const Text('Update PIN'),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      current.dispose();
      next.dispose();
      confirm.dispose();
    });
    if (values == null || !context.mounted) {
      return;
    }
    if (values[1] != values[2]) {
      message(context, 'The new PINs do not match.');
      return;
    }
    try {
      await vault.changeCurrentPin(currentPin: values[0], newPin: values[1]);
      if (context.mounted) {
        message(context, 'PIN updated. Your files are unchanged.');
      }
    } catch (error) {
      if (context.mounted) message(context, error);
    }
  }

  Widget _pinField(TextEditingController controller, String label) => TextField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 12,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, counterText: ''),
  );

  Future<void> selfie(BuildContext context, bool value) async {
    if (value) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (context.mounted) {
          message(context, 'Camera access is required for break-in capture.');
        }
        return;
      }
    }
    await vault.setSecurity(selfie: value);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vault,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('Peace of mind', style: editorial(24))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
        children: [
          PaperCard(
            color: ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: khaki, size: 36),
                const SizedBox(height: 16),
                Text(
                  'Private by design.',
                  style: editorial(30, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your files and their names are encrypted on this device. No sign-in. No connection. No remote access.',
                  style: TextStyle(color: Colors.white60, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Panic flip'),
            subtitle: const Text(
              'Face-down returns to the calculator immediately.',
            ),
            value: vault.panicEnabled,
            onChanged: vault.decoy
                ? null
                : (value) => vault.setSecurity(panic: value),
          ),
          const Divider(color: border),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Break-in capture'),
            subtitle: const Text(
              'Front-camera evidence after three failed PIN attempts. Requires permission; system camera indicators may appear.',
            ),
            value: vault.selfieEnabled,
            onChanged: vault.decoy ? null : (value) => selfie(context, value),
          ),
          if (!vault.decoy) ...[
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_camera_front_outlined),
              title: const Text('Security activity'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => EvidenceScreen(vault: vault),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text('PIN management', style: editorial(23)),
          const SizedBox(height: 8),
          Text(
            'Change the PIN for the ${vault.decoy ? 'decoy' : 'main'} vault that is open now. Your encrypted files stay in place.',
            style: const TextStyle(color: muted, height: 1.6),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.password_rounded),
            title: Text(vault.decoy ? 'Change decoy PIN' : 'Change main PIN'),
            subtitle: const Text('Current PIN required · 4–12 digits'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _changePin(context),
          ),
          const SizedBox(height: 12),
          Text('A few things to know', style: editorial(23)),
          const SizedBox(height: 12),
          const Text(
            '• The vault locks when the app goes into the background.\n\n• Short PINs are easier to guess. Use a long, unique PIN. Failed attempts have a persistent cooldown.\n\n• There is no cloud backup or PIN recovery. Uninstalling or losing this device may permanently lose your files.\n\n• Audio and video playback briefly use private cache files, removed on close, lock, and launch. Photos stay in memory.\n\n• Removing gallery originals requires your confirmation and may leave copies in Recently Deleted.\n\n• Encryption cannot protect an unlocked vault or a compromised device.',
            style: TextStyle(color: muted, height: 1.7),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: vault.lock,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Lock now'),
          ),
        ],
      ),
    ),
  );
}

class EvidenceScreen extends StatefulWidget {
  final Vault vault;
  const EvidenceScreen({super.key, required this.vault});
  @override
  State<EvidenceScreen> createState() => _EvidenceState();
}

class _EvidenceState extends State<EvidenceScreen> {
  late final activity = widget.vault.evidence();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Security activity', style: editorial(24))),
    body: FutureBuilder(
      future: activity,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to read security activity.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined, color: green, size: 60),
                SizedBox(height: 16),
                Text('No break-in photos recorded.'),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
          children: snapshot.data!
              .map(
                (record) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: PaperCard(
                    child: Column(
                      children: [
                        Image.memory(
                          record.$2,
                          height: 300,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(record.$1.toLocal().toString().split('.').first),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}
