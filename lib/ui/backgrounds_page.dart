import 'package:flutter/material.dart';

import 'scope.dart';
import 'start_page.dart';
import 'widgets.dart';

/// Eigene Hintergrundbilder verwalten.
class BackgroundsPage extends StatelessWidget {
  const BackgroundsPage({super.key});

  Future<void> _confirmDelete(BuildContext context, String id) async {
    final store = StoreScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bild entfernen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entfernen')),
        ],
      ),
    );
    if (ok == true) await store.removeBackground(id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ids = store.backgroundIds;
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Bilder')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addOwnBackground(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Bild'),
      ),
      body: ids.isEmpty
          ? const EmptyState(
              icon: Icons.collections_outlined,
              title: 'Noch keine eigenen Bilder',
              subtitle: 'Füge z. B. deine Lieblings-Anime-Wallpaper hinzu. '
                  'Sie wechseln jeden Tag.',
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 9 / 16,
              ),
              itemCount: ids.length,
              itemBuilder: (context, i) {
                final bytes = store.backgroundImage(ids[i]);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (bytes != null)
                        Image.memory(bytes, fit: BoxFit.cover)
                      else
                        const ColoredBox(color: Colors.black26),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Entfernen',
                          onPressed: () => _confirmDelete(context, ids[i]),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
