import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/vault.dart';
import 'design.dart';

class GalleryImport extends StatefulWidget {
  final Vault vault;
  final String folder;
  const GalleryImport({super.key, required this.vault, required this.folder});
  @override
  State<GalleryImport> createState() => _GalleryImportState();
}

class _GalleryImportState extends State<GalleryImport> {
  final ImagePicker _picker = ImagePicker();
  bool importing = false;
  int completed = 0;
  int total = 0;
  String status = '';
  String? error;
  int lastImportedCount = 0;

  Future<void> pickAndImportMedia({
    bool photosOnly = false,
    bool videosOnly = false,
  }) async {
    try {
      setState(() {
        error = null;
        status = 'Opening system picker…';
      });

      List<XFile> files = [];
      if (photosOnly) {
        files = await _picker.pickMultiImage();
      } else if (videosOnly) {
        final video = await _picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          files = [video];
        }
      } else {
        files = await _picker.pickMultipleMedia();
      }

      if (files.isEmpty) {
        if (mounted) setState(() => status = '');
        return;
      }

      setState(() {
        importing = true;
        total = files.length;
        completed = 0;
        status = 'Encrypting 1 of $total…';
      });

      final generation = widget.vault.session;
      var imported = 0;

      for (var i = 0; i < files.length; i++) {
        if (!widget.vault.unlocked || generation != widget.vault.session) {
          return;
        }
        final xFile = files[i];
        final size = await xFile.length();
        if (size > 150 * 1024 * 1024) {
          throw StateError('File "${xFile.name}" exceeds the 150 MB limit.');
        }

        final bytes = await xFile.readAsBytes();
        final ext = xFile.path.contains('.')
            ? xFile.path.split('.').last.toLowerCase()
            : 'jpg';
        final isVideo =
            ['mp4', 'mov', 'm4v', 'mkv', 'webm', '3gp'].contains(ext);

        try {
          await widget.vault.importBytes(
            bytes,
            name: xFile.name.isNotEmpty
                ? xFile.name
                : (isVideo ? 'Video' : 'Photo'),
            kind: isVideo ? 'video' : 'photo',
            folder: widget.folder,
            extension: ext,
          );
          imported++;
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }

        if (mounted) {
          setState(() {
            completed = i + 1;
            status = 'Secured $completed of $total';
          });
        }
      }

      if (mounted) {
        setState(() {
          importing = false;
          lastImportedCount = imported;
          status = 'Successfully encrypted $imported items into ${widget.folder}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          importing = false;
          error = e.toString();
        });
        message(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Import into ${widget.folder}', style: editorial(22)),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PaperCard(
            color: ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.photo_library_outlined, color: khaki, size: 30),
                    Spacer(),
                    Tag('SYSTEM PICKER', color: khaki),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Private System Picker',
                  style: editorial(26, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Select photos and videos safely using the Android system photo picker. Only the media you explicitly choose is encrypted into your vault.',
                  style: TextStyle(color: Colors.white70, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          if (importing) ...[
            PaperCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Securing Media…', style: editorial(20)),
                  const SizedBox(height: 8),
                  Text(
                    status,
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: total > 0 ? completed / total : null,
                    color: green,
                    backgroundColor: border,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else if (lastImportedCount > 0) ...[
            PaperCard(
              color: green.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: green, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (error != null) ...[
            PaperCard(
              color: Colors.red.shade50,
              child: Text(
                error!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text('Select media to encrypt', style: editorial(20)),
          const SizedBox(height: 14),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: border),
            ),
            tileColor: Colors.white,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: khaki.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.perm_media_outlined, color: khaki),
            ),
            title: const Text(
              'Select Photos & Videos',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Choose multiple photos and videos at once'),
            trailing: const Icon(Icons.chevron_right),
            enabled: !importing,
            onTap: () => pickAndImportMedia(),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: border),
            ),
            tileColor: Colors.white,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_outlined, color: green),
            ),
            title: const Text(
              'Photos Only',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Pick one or more high-resolution photos'),
            trailing: const Icon(Icons.chevron_right),
            enabled: !importing,
            onTap: () => pickAndImportMedia(photosOnly: true),
          ),
          const SizedBox(height: 12),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: border),
            ),
            tileColor: Colors.white,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.videocam_outlined, color: ink),
            ),
            title: const Text(
              'Video Only',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Choose a video to securely lock'),
            trailing: const Icon(Icons.chevron_right),
            enabled: !importing,
            onTap: () => pickAndImportMedia(videosOnly: true),
          ),
          if (lastImportedCount > 0) ...[
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done),
              label: const Text('Done & Return to Vault'),
            ),
          ],
        ],
      ),
    ),
  );
}
