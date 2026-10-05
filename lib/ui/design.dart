import 'package:flutter/material.dart';

const linen = Color(0xFFFBF9F5);
const ink = Color(0xFF141414);
const khaki = Color(0xFFA68A56);
const muted = Color(0xFF75736E);
const border = Color(0xFFECE8E0);
const green = Color(0xFF2E6B4D);
TextStyle editorial(double size, {Color color = ink}) => TextStyle(
  fontFamily: 'PlayfairDisplay',
  fontFamilyFallback: const ['serif'],
  fontSize: size,
  fontWeight: FontWeight.w500,
  letterSpacing: -.6,
  color: color,
);
ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'PlusJakartaSans',
  scaffoldBackgroundColor: linen,
  colorScheme: const ColorScheme.light(
    primary: ink,
    secondary: khaki,
    surface: linen,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: linen,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: border),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  ),
);

class Tag extends StatelessWidget {
  final String label;
  final Color color;
  const Tag(this.label, {super.key, this.color = green});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: .6,
      ),
    ),
  );
}

class PaperCard extends StatelessWidget {
  final Widget child;
  final Color color;
  const PaperCard({super.key, required this.child, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

void message(BuildContext context, Object error) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('FormatException: ', ''),
        ),
      ),
    );
  }
}

Future<String?> textPrompt(
  BuildContext context,
  String title, {
  String label = 'Name',
  bool secret = false,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: editorial(24)),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: secret,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // Dispose after the dialog route finishes animating.
  Future.delayed(const Duration(milliseconds: 300), controller.dispose);
  return result;
}
