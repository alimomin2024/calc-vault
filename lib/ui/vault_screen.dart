import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/vault.dart';
import 'audio_note.dart';
import 'design.dart';
import 'gallery_import.dart';
import 'record_editor.dart';
import 'security_screen.dart';
import 'viewer.dart';

class VaultScreen extends StatefulWidget {
  final Vault vault;
  const VaultScreen({super.key, required this.vault});
  @override
  State<VaultScreen> createState() => _VaultState();
}

class _VaultState extends State<VaultScreen> {
  String category = 'All', folder = 'All folders', search = '';
  bool busy = false;
  @override
  void initState() {
    super.initState();
    seedDecoy();
  }

  Future<void> seedDecoy() async {
    if (!widget.vault.decoy || widget.vault.items.isNotEmpty) {
      return;
    }
    try {
      for (final sample in ['afternoon', 'coast']) {
        final bytes = await rootBundle.load('assets/decoy/$sample.png');
        await widget.vault.importBytes(
          bytes.buffer.asUint8List(),
          name: sample == 'coast' ? 'By the coast' : 'Sunny afternoon',
          kind: 'photo',
          folder: 'Personal',
          extension: 'png',
        );
      }
    } catch (_) {}
  }

  String get destination => folder == 'All folders' ? 'Personal' : folder;
  Future<void> addFolder() async {
    final name = await textPrompt(context, 'A new collection');
    if (name != null && name.isNotEmpty) {
      try {
        await widget.vault.addFolder(name);
      } catch (e) {
        if (mounted) {
          message(context, e);
        }
      }
    }
  }

  void push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  void add() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: linen,
    showDragHandle: true,
    builder: (context) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Keep something private', style: editorial(26)),
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Photos & videos'),
              subtitle: const Text('Import from device gallery'),
              onTap: () {
                Navigator.pop(context);
                push(GalleryImport(vault: widget.vault, folder: destination));
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_none),
              title: const Text('Record an audio note'),
              onTap: () {
                Navigator.pop(context);
                push(AudioNote(vault: widget.vault, folder: destination));
              },
            ),
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: const Text('Password or card'),
              onTap: () {
                Navigator.pop(context);
                push(RecordEditor(vault: widget.vault, folder: destination));
              },
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.vault,
    builder: (context, _) {
      final vault = widget.vault;
      final kinds = {
        'Photos': 'photo',
        'Videos': 'video',
        'Audio': 'audio',
        'Records': 'record',
      };
      final visible = vault.items
          .where(
            (item) =>
                (category == 'All' || item.kind == kinds[category]) &&
                (folder == 'All folders' || item.folder == folder) &&
                item.name.toLowerCase().contains(search.toLowerCase()),
          )
          .toList()
          .reversed
          .toList();
      final total = vault.items.fold<int>(0, (sum, item) => sum + item.size);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            vault.lock();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 24),
                const SizedBox(width: 10),
                Text('CalcVault', style: editorial(23)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Security',
                onPressed: () => push(SecurityScreen(vault: vault)),
                icon: const Icon(Icons.tune_rounded),
              ),
              IconButton(
                tooltip: 'Lock vault',
                onPressed: vault.lock,
                icon: const Icon(Icons.lock_outline),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            onPressed: busy ? null : add,
            icon: const Icon(Icons.add),
            label: Text(busy ? 'Saving…' : 'Add to vault'),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'YOUR PRIVATE COLLECTION',
                                  style: TextStyle(
                                    color: muted,
                                    letterSpacing: 1.5,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Tag('OFFLINE'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text('Only for your eyes.', style: editorial(36)),
                          const SizedBox(height: 8),
                          const Text(
                            'A quiet place for the things that matter.',
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          PaperCard(
                            color: ink,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'SAFELY TUCKED AWAY',
                                        style: TextStyle(
                                          color: khaki,
                                          fontSize: 9,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${vault.items.length} private items',
                                        style: editorial(
                                          26,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${(total / 1024 / 1024).toStringAsFixed(1)} MB · encrypted on this device',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.shield_outlined,
                                  color: khaki,
                                  size: 46,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            onChanged: (value) =>
                                setState(() => search = value),
                            decoration: const InputDecoration(
                              hintText: 'Find something private',
                              prefixIcon: Icon(Icons.search, size: 21),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 18),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  [
                                        'All',
                                        'Photos',
                                        'Videos',
                                        'Audio',
                                        'Records',
                                      ]
                                      .map(
                                        (name) => Padding(
                                          padding: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: ChoiceChip(
                                            label: Text(name),
                                            selected: category == name,
                                            onSelected: (_) =>
                                                setState(() => category = name),
                                            selectedColor: ink,
                                            labelStyle: TextStyle(
                                              color: category == name
                                                  ? Colors.white
                                                  : muted,
                                              fontSize: 12,
                                            ),
                                            showCheckmark: false,
                                            side: BorderSide(
                                              color: category == name
                                                  ? ink
                                                  : border,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: folder,
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 14,
                                      fontFamily: 'PlusJakartaSans',
                                    ),
                                    items: ['All folders', ...vault.folders]
                                        .map(
                                          (name) => DropdownMenuItem(
                                            value: name,
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.folder_outlined,
                                                  size: 18,
                                                  color: khaki,
                                                ),
                                                const SizedBox(width: 10),
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) =>
                                        setState(() => folder = value!),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'New folder',
                                onPressed: addFolder,
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF4F1EA),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: khaki,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              vault.items.isEmpty
                                  ? 'Your space is ready.'
                                  : 'Nothing here just yet.',
                              style: editorial(26),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              vault.items.isEmpty
                                  ? 'Add photos, memories, notes and secrets.\nThey stay with you, and only you.'
                                  : 'Try another collection or search.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                height: 1.7,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextButton.icon(
                              onPressed: add,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add your first item'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid.builder(
                      itemCount: visible.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width > 600
                            ? 3
                            : 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: .84,
                      ),
                      itemBuilder: (context, index) => VaultTile(
                        key: ValueKey(visible[index].id),
                        vault: vault,
                        item: visible[index],
                        onTap: () => push(
                          ItemViewer(vault: vault, item: visible[index]),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 160)),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class VaultTile extends StatefulWidget {
  final Vault vault;
  final VaultItem item;
  final VoidCallback onTap;
  const VaultTile({
    super.key,
    required this.vault,
    required this.item,
    required this.onTap,
  });
  @override
  State<VaultTile> createState() => _TileState();
}

class _TileState extends State<VaultTile> {
  late final Future<Uint8List>? photo = widget.item.kind == 'photo'
      ? widget.vault.read(widget.item)
      : null;
  Uint8List? loaded;
  @override
  void dispose() {
    loaded?.fillRange(0, loaded!.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: border),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: const Color(0xFFF4F1EA),
              child: photo != null
                  ? FutureBuilder(
                      future: photo,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          loaded = snapshot.data;
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
                            cacheWidth: 400,
                            errorBuilder: (context, _, _) => const Icon(
                              Icons.broken_image_outlined,
                              color: muted,
                            ),
                          );
                        }
                        return const Icon(Icons.image_outlined, color: khaki);
                      },
                    )
                  : Center(
                      child: Icon(
                        switch (widget.item.kind) {
                          'video' => Icons.play_circle_outline,
                          'audio' => Icons.graphic_eq,
                          _ => Icons.key_outlined,
                        },
                        color: khaki,
                        size: 42,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.item.folder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
