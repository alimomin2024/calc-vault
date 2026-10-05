import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
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
  List<AssetEntity> assets = [];
  final selected = <String>{};
  AssetPathEntity? album;
  int page = 0;
  bool loading = true, importing = false, more = true;
  int importCompleted = 0, importTotal = 0;
  String importStatus = '';
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await widget.vault.galleryCacheCleanup;
      if (album == null) {
        final permission = await PhotoManager.requestPermissionExtend();
        if (!permission.hasAccess) {
          throw StateError(
            'Allow photo access in device settings to import media.',
          );
        }
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          onlyAll: true,
        );
        if (albums.isNotEmpty) {
          album = albums.first;
        }
      }
      final next = await album?.getAssetListPaged(page: page, size: 60) ?? [];
      if (mounted) {
        setState(() {
          assets.addAll(next);
          more = next.length == 60;
          page++;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          loading = false;
        });
      }
    }
  }

  Future<void> import() async {
    final chosen = assets.where((a) => selected.contains(a.id)).toList();
    if (chosen.isEmpty) {
      return;
    }
    setState(() {
      importing = true;
      importCompleted = 0;
      importTotal = chosen.length;
      importStatus = 'Preparing 1 of $importTotal';
    });
    final generation = widget.vault.session;
    final imported = <String>[];
    try {
      for (var index = 0; index < chosen.length; index++) {
        final asset = chosen[index];
        if (!widget.vault.unlocked || generation != widget.vault.session) {
          return;
        }
        if (mounted) {
          setState(() => importStatus = 'Loading ${index + 1} of $importTotal');
        }
        // The vendored PhotoKit plugin disables all network access.
        if (!await asset.isLocallyAvailable(
          isOrigin: true,
          withSubtype: true,
        )) {
          throw StateError('This item is not stored on this device.');
        }
        final file = await asset.loadFile(isOrigin: true, withSubtype: true);
        if (file == null) {
          throw StateError(
            'This item is not available on device. Download it in Photos first.',
          );
        }
        final size = await file.length();
        if (size > 150 * 1024 * 1024) {
          throw StateError('File exceeds the 150 MB limit.');
        }
        final name = await asset.titleAsync;
        if (mounted) {
          setState(() => importStatus = 'Reading ${index + 1} of $importTotal');
        }
        final bytes = await file.readAsBytes();
        try {
          if (mounted) {
            setState(
              () => importStatus = 'Encrypting ${index + 1} of $importTotal',
            );
          }
          await widget.vault.importBytes(
            bytes,
            name: name.isEmpty ? 'Media' : name,
            kind: asset.type == AssetType.video ? 'video' : 'photo',
            folder: widget.folder,
            extension: file.path.split('.').last,
          );
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
        imported.add(asset.id);
        if (mounted) {
          setState(() {
            importCompleted = index + 1;
            importStatus = 'Saved $importCompleted of $importTotal';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        message(context, e);
      }
    }
    if (!mounted ||
        !widget.vault.unlocked ||
        generation != widget.vault.session) {
      return;
    }
    if (imported.isNotEmpty) {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Saved to your vault', style: editorial(24)),
          content: Text(
            '${imported.length} items are encrypted and saved on this device. Delete the originals from your device gallery? Your operating system may ask for confirmation. Deleted originals may remain in Recently Deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep originals'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete originals'),
            ),
          ],
        ),
      );
      if (remove == true &&
          widget.vault.unlocked &&
          generation == widget.vault.session) {
        try {
          final removed = await PhotoManager.editor.deleteWithIds(imported);
          if (mounted && removed.length != imported.length) {
            message(
              context,
              'Some originals were kept. Your encrypted copies are safe.',
            );
          }
        } catch (e) {
          if (mounted) {
            message(context, 'Encrypted copies saved. Originals were kept: $e');
          }
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } else if (mounted) {
      setState(() {
        importing = false;
        importStatus = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('From your gallery', style: editorial(24))),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (importing) ...[
              Text(
                importStatus,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(
                color: khaki,
                backgroundColor: border,
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: selected.isEmpty || importing ? null : import,
              icon: const Icon(Icons.lock_outline),
              label: Text(
                importing
                    ? 'Encrypting…'
                    : 'Import ${selected.length} selected',
              ),
            ),
          ],
        ),
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: PhotoManager.openSetting,
                    child: const Text('Device settings'),
                  ),
                ],
              ),
            ),
          )
        : CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 18),
                  child: Text(
                    'Only local photos and videos. Nothing is uploaded.',
                    style: TextStyle(color: muted),
                  ),
                ),
              ),
              if (assets.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No local media available.')),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.builder(
                  itemCount: assets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                  ),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    final active = selected.contains(asset.id);
                    return GestureDetector(
                      onTap: importing
                          ? null
                          : () => setState(() {
                              active
                                  ? selected.remove(asset.id)
                                  : selected.add(asset.id);
                            }),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FutureBuilder(
                            future: asset.thumbnailDataWithSize(
                              const ThumbnailSize(220, 220),
                            ),
                            builder: (context, snapshot) => snapshot.hasData
                                ? Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  )
                                : const ColoredBox(
                                    color: border,
                                    child: Icon(Icons.image_outlined),
                                  ),
                          ),
                          if (asset.type == AssetType.video)
                            const Positioned(
                              bottom: 8,
                              left: 8,
                              child: Icon(Icons.videocam, color: Colors.white),
                            ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              active
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: active ? khaki : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (more)
                SliverToBoxAdapter(
                  child: TextButton(
                    onPressed: importing ? null : load,
                    child: const Text('Load more'),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
  );
}
