import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/vault.dart';
import 'design.dart';

class RecordEditor extends StatefulWidget {
  final Vault vault;
  final String folder;
  const RecordEditor({super.key, required this.vault, required this.folder});
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final title = TextEditingController(),
      username = TextEditingController(),
      secret = TextEditingController(),
      notes = TextEditingController(),
      expiry = TextEditingController();
  String type = 'Password';
  bool busy = false;
  @override
  void dispose() {
    for (final c in [title, username, secret, notes, expiry]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || secret.text.isEmpty) {
      message(context, 'Add a title and a secret.');
      return;
    }
    setState(() => busy = true);
    try {
      final fields = type == 'Password'
          ? {
              'Type': type,
              'Username': username.text,
              'Password': secret.text,
              'Notes': notes.text,
            }
          : {
              'Type': type,
              'Cardholder': username.text,
              'Card number': secret.text,
              'Expiry': expiry.text,
              'Notes': notes.text,
            };
      await widget.vault.importBytes(
        Uint8List.fromList(utf8.encode(jsonEncode(fields))),
        name: title.text.trim(),
        kind: 'record',
        folder: widget.folder,
        extension: 'json',
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        message(context, e);
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('A private record', style: editorial(24))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
      children: [
        const Tag('AES-256 ENCRYPTED'),
        const SizedBox(height: 24),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'Password',
              label: Text('Password'),
              icon: Icon(Icons.key_outlined),
            ),
            ButtonSegment(
              value: 'Card',
              label: Text('Card'),
              icon: Icon(Icons.credit_card),
            ),
          ],
          selected: {type},
          onSelectionChanged: (value) => setState(() => type = value.first),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: username,
          decoration: InputDecoration(
            labelText: type == 'Password' ? 'Username / email' : 'Cardholder',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: secret,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: type == 'Password' ? 'Password' : 'Card number',
          ),
        ),
        if (type == 'Card') ...[
          const SizedBox(height: 16),
          TextField(
            controller: expiry,
            decoration: const InputDecoration(labelText: 'Expiry · MM/YY'),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: notes,
          minLines: 3,
          maxLines: 6,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Secure notes'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : save,
          icon: const Icon(Icons.lock_outline),
          label: Text(busy ? 'Encrypting…' : 'Save encrypted record'),
        ),
      ],
    ),
  );
}
