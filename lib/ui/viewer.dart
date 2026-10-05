import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/vault.dart';
import 'design.dart';

class ItemViewer extends StatefulWidget {
  final Vault vault;
  final VaultItem item;
  const ItemViewer({super.key, required this.vault, required this.item});
  @override
  State<ItemViewer> createState() => _ViewerState();
}

class _ViewerState extends State<ItemViewer> {
  Uint8List? bytes;
  VideoPlayerController? video;
  AudioPlayer? audio;
  File? file;
  String? error;
  bool playing = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      if (['photo', 'record'].contains(widget.item.kind)) {
        final data = await widget.vault.read(widget.item);
        if (mounted) {
          setState(() => bytes = data);
        }
      } else {
        final preview = await widget.vault.preview(widget.item);
        if (!mounted) {
          if (await preview.exists()) {
            await preview.delete();
          }
          return;
        }
        file = preview;
        if (widget.item.kind == 'video') {
          final controller = VideoPlayerController.file(preview);
          video = controller;
          await controller.initialize();
          if (!mounted) {
            return;
          }
          controller.addListener(update);
        } else {
          audio = AudioPlayer();
          await audio!.setSource(DeviceFileSource(preview.path));
          audio!.onPlayerStateChanged.listen((state) {
            if (mounted) {
              setState(() => playing = state == PlayerState.playing);
            }
          });
        }
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    }
  }

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    video?.removeListener(update);
    final v = video;
    final a = audio;
    final f = file;
    Future<void>(() async {
      await v?.dispose();
      await a?.dispose();
      if (f != null && await f.exists()) {
        await f.delete();
      }
    });
    bytes?.fillRange(0, bytes!.length, 0);
    super.dispose();
  }

  Future<void> remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text(
          'This removes the encrypted copy. It cannot be recovered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) {
      return;
    }
    try {
      await widget.vault.delete(widget.item);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        message(context, e);
      }
    }
  }

  Future<void> move() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: widget.vault.folders
            .map(
              (f) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(f),
                onTap: () => Navigator.pop(context, f),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      try {
        await widget.vault.move(widget.item, selected);
        if (mounted) {
          message(context, 'Moved to $selected');
        }
      } catch (e) {
        if (mounted) {
          message(context, e);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final dark = item.kind != 'record';
    Widget content = const Center(
      child: CircularProgressIndicator(color: khaki),
    );
    if (error != null) {
      content = Center(
        child: Text(error!, style: TextStyle(color: dark ? Colors.white : ink)),
      );
    } else if (item.kind == 'photo' && bytes != null) {
      content = InteractiveViewer(
        minScale: .5,
        maxScale: 6,
        child: Center(
          child: Image.memory(
            bytes!,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => const Text(
              'Unsupported image format',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    } else if (item.kind == 'record' && bytes != null) {
      final fields = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes!)));
      content = ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 56),
        children: [
          Text(item.name, style: editorial(32)),
          const SizedBox(height: 12),
          const Tag('ENCRYPTED RECORD'),
          const SizedBox(height: 24),
          ...fields.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PaperCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: muted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else if (video?.value.isInitialized == true) {
      final v = video!;
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InteractiveViewer(
            maxScale: 4,
            child: AspectRatio(
              aspectRatio: v.value.aspectRatio,
              child: VideoPlayer(v),
            ),
          ),
          const SizedBox(height: 20),
          VideoProgressIndicator(
            v,
            allowScrubbing: true,
            colors: const VideoProgressColors(playedColor: khaki),
          ),
          IconButton(
            iconSize: 52,
            color: Colors.white,
            onPressed: () => v.value.isPlaying ? v.pause() : v.play(),
            icon: Icon(
              v.value.isPlaying
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
            ),
          ),
        ],
      );
    } else if (audio != null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.graphic_eq, size: 100, color: khaki),
            const SizedBox(height: 24),
            Text(item.name, style: editorial(26, color: Colors.white)),
            const SizedBox(height: 24),
            IconButton(
              iconSize: 64,
              color: Colors.white,
              onPressed: () => playing ? audio!.pause() : audio!.resume(),
              icon: Icon(
                playing
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: dark ? ink : linen,
      appBar: AppBar(
        backgroundColor: dark ? ink : linen,
        foregroundColor: dark ? Colors.white : ink,
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Move to folder',
            onPressed: move,
            icon: const Icon(Icons.drive_file_move_outlined),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: remove,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: 'Lock vault',
            onPressed: widget.vault.lock,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: content,
    );
  }
}
