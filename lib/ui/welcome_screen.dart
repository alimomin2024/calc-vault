import 'package:flutter/material.dart';
import '../core/vault.dart';
import 'design.dart';

class WelcomeScreen extends StatelessWidget {
  final Vault vault;
  final VoidCallback onContinue;
  const WelcomeScreen({
    super.key,
    required this.vault,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(26, 28, 26, 32),
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/branding/calculator_icon.png',
                    width: 42,
                    height: 42,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'CALCVAULT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                      color: ink,
                    ),
                  ),
                  const Spacer(),
                  const Tag('OFFLINE'),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: Image.asset(
                  'assets/branding/calculator_icon.png',
                  width: 142,
                  height: 142,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'A familiar calculator.\nA little more privacy.',
                textAlign: TextAlign.center,
                style: editorial(34),
              ),
              const SizedBox(height: 12),
              const Text(
                'Use the calculator as usual. A PIN you choose opens a separate, encrypted space stored on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, height: 1.7),
              ),
              const SizedBox(height: 24),
              const PaperCard(
                child: Column(
                  children: [
                    _WelcomeRow(
                      icon: Icons.calculate_outlined,
                      title: 'Everyday calculations',
                      detail: 'Standard and scientific functions stay at hand.',
                    ),
                    SizedBox(height: 18),
                    _WelcomeRow(
                      icon: Icons.phonelink_lock_outlined,
                      title: 'Stored on this device',
                      detail:
                          'Your vault is encrypted locally; there are no accounts or cloud sync.',
                    ),
                    SizedBox(height: 18),
                    _WelcomeRow(
                      icon: Icons.tune_rounded,
                      title: 'You choose what to allow',
                      detail:
                          'Photo, camera, and microphone access are requested only for related features.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Setup asks you to create a main PIN and a different decoy PIN. Keep both somewhere safe: there is no PIN recovery.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  await vault.markWelcomeSeen();
                  if (context.mounted) onContinue();
                },
                child: const Text('Continue to setup'),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'No internet connection is needed.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WelcomeRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  const _WelcomeRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: khaki, size: 23),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              detail,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    ],
  );
}
