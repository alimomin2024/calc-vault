import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../core/vault.dart';
import 'design.dart';

class AudioNote extends StatefulWidget {
  final Vault vault;
  final String folder;
  const AudioNote({super.key, required this.vault, required this.folder});
  @override
  State<AudioNote> createState() => _AudioNoteState();
}

class _AudioNoteState extends State<AudioNote> {
  final recorder = AudioRecorder();
  final title = TextEditingController(text: 'Audio note');
  bool recording = false, busy = false;
  String? path;
  Future<void> start() async {
    setState(() => busy = true);
    try {
      final generation = widget.vault.session;
      if (!await recorder.hasPermission()) {
        throw StateError('Microphone access was denied.');
      }
      if (!mounted ||
          !widget.vault.unlocked ||
          generation != widget.vault.session) {
        return;
      }
      path =
          '${widget.vault.cache.path}/recording-${DateTime.now().microsecondsSinceEpoch}.m4a';
      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path!,
      );
      if (mounted) {
        setState(() => recording = true);
      }
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

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final result = await recorder.stop();
      if (result == null) {
        throw StateError('No recording was created.');
      }
      final file = File(result);
      final size = await file.length();
      if (size > 150 * 1024 * 1024) {
        throw const FormatException('Maximum recording size is 150 MB.');
      }
      final bytes = await file.readAsBytes();
      try {
        await widget.vault.importBytes(
          bytes,
          name: title.text.trim().isEmpty ? 'Audio note' : title.text.trim(),
          kind: 'audio',
          folder: widget.folder,
          extension: 'm4a',
        );
      } finally {
        bytes.fillRange(0, bytes.length, 0);
      }
      if (await file.exists()) {
        await file.delete();
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        message(context, e);
        setState(() {
          recording = false;
          busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    title.dispose();
    final temp = path;
    Future<void>(() async {
      await recorder.cancel();
      await recorder.dispose();
      if (temp != null) {
        final file = File(temp);
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Audio notes', style: editorial(24))),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 56),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.graphic_eq, size: 100, color: recording ? khaki : muted),
        const SizedBox(height: 28),
        Center(
          child: Text(
            recording ? 'A moment, kept private.' : 'Thoughts worth keeping.',
            style: editorial(30),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Microphone audio is recorded locally, then encrypted when you save. Locking cancels an unsaved recording.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Note title'),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: busy
              ? null
              : recording
              ? save
              : start,
          icon: Icon(recording ? Icons.stop_circle_outlined : Icons.mic_none),
          label: Text(
            busy
                ? 'One moment…'
                : recording
                ? 'Stop & encrypt'
                : 'Start recording',
          ),
        ),
      ],
    ),
  );
}
