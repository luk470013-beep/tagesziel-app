import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../quotes.dart';
import '../store.dart';
import 'scope.dart';

/// Wählt ein Bild aus der Galerie, verkleinert es und speichert es.
Future<bool> pickImageInto(BuildContext context, String key,
    {required double maxSize}) async {
  final store = StoreScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: maxSize,
      maxHeight: maxSize,
      imageQuality: 82,
      requestFullMetadata: false,
    );
    if (x == null) return false;
    final bytes = await x.readAsBytes();
    await store.setImage(key, bytes);
    return true;
  } catch (e) {
    messenger.showSnackBar(
        const SnackBar(content: Text('Das Bild konnte nicht geladen werden.')));
    return false;
  }
}

/// Hintergrund-Optionen (auch aus den Einstellungen aufrufbar).
Future<void> showBackgroundOptions(BuildContext context) async {
  final store = StoreScope.read(context);
  final hasOwn = store.image(Store.kImgBackground) != null;
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final mode = store.settings.bgMode;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Hintergrund der Startseite',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Jeden Tag ein neues Foto'),
              subtitle: const Text('Braucht Internet'),
              trailing: mode == BgMode.daily ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, 'daily'),
            ),
            if (hasOwn)
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Mein eigenes Bild'),
                trailing: mode == BgMode.own ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, 'own'),
              ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: Text(hasOwn
                  ? 'Anderes Bild aus Galerie wählen'
                  : 'Eigenes Bild aus Galerie wählen'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (hasOwn)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Eigenes Bild entfernen'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (!context.mounted || choice == null) return;
  switch (choice) {
    case 'daily':
      store.updateSettings((s) => s.bgMode = BgMode.daily);
    case 'own':
      store.updateSettings((s) => s.bgMode = BgMode.own);
    case 'pick':
      final ok =
          await pickImageInto(context, Store.kImgBackground, maxSize: 1600);
      if (ok) store.updateSettings((s) => s.bgMode = BgMode.own);
    case 'remove':
      await store.setImage(Store.kImgBackground, null);
      store.updateSettings((s) => s.bgMode = BgMode.daily);
  }
}

class StartPage extends StatelessWidget {
  const StartPage({super.key, required this.onOpenGoals});

  final VoidCallback onOpenGoals;

  Future<void> _avatarOptions(BuildContext context) async {
    final store = StoreScope.read(context);
    if (store.image(Store.kImgAvatar) == null) {
      await pickImageInto(context, Store.kImgAvatar, maxSize: 600);
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Anderes Bild wählen'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Bild entfernen'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (choice == 'pick') {
      await pickImageInto(context, Store.kImgAvatar, maxSize: 600);
    } else if (choice == 'remove') {
      await store.setImage(Store.kImgAvatar, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final today = dayKey(now);
    final bg = store.settings.bgMode == BgMode.own
        ? store.image(Store.kImgBackground)
        : null;
    final avatar = store.image(Store.kImgAvatar);
    final name = store.settings.name.trim();
    final goals = store.goalsFor(today);
    final open = goals.where((g) => !g.done).toList();
    final done = goals.length - open.length;
    final gold = Theme.of(context).colorScheme.primary;

    const shadow = [Shadow(blurRadius: 12, color: Colors.black54)];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Background(bytes: bg, seed: today),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x99000000),
                  Color(0x22000000),
                  Color(0x33000000),
                  Color(0xDD000000),
                ],
                stops: [0, 0.3, 0.55, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---------- Begrüßung ----------
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name.isEmpty
                                          ? greeting(now)
                                          : '${greeting(now)}, $name',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                        shadows: shadow,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fmtDayLong(now),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                        shadows: shadow,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Hintergrund ändern',
                                onPressed: () => showBackgroundOptions(context),
                                icon: const Icon(Icons.wallpaper,
                                    color: Colors.white),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(height: 32),
                          // ---------- Eigenes Bild ----------
                          Center(
                            child: _Avatar(
                              bytes: avatar,
                              gold: gold,
                              onTap: () => _avatarOptions(context),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // ---------- Spruch des Tages ----------
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '„${quoteFor(dayOfYear(now))}“',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                                shadows: shadow,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 32),
                          // ---------- Heute ----------
                          _TodayCard(
                            open: open,
                            done: done,
                            total: goals.length,
                            gold: gold,
                            onOpen: onOpenGoals,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background({required this.bytes, required this.seed});

  final Uint8List? bytes;
  final String seed;

  static const _fallback = DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A2214), Color(0xFF111111), Color(0xFF000000)],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        _fallback,
        Image.network(
          'https://picsum.photos/seed/tagesziele-$seed/1080/1920',
          fit: BoxFit.cover,
          frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 600),
            child: child,
          ),
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.bytes, required this.gold, required this.onTap});

  final Uint8List? bytes;
  final Color gold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const size = 150.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: gold, width: 2),
          color: Colors.white.withValues(alpha: 0.10),
          boxShadow: const [
            BoxShadow(blurRadius: 24, color: Colors.black54, offset: Offset(0, 8)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: bytes != null
              ? Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true)
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined,
                        color: Colors.white70, size: 36),
                    SizedBox(height: 8),
                    Text('Eigenes Bild',
                        style: TextStyle(color: Colors.white70)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.open,
    required this.done,
    required this.total,
    required this.gold,
    required this.onOpen,
  });

  final List<Entry> open;
  final int done;
  final int total;
  final Color gold;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final String status;
    if (total == 0) {
      status = 'Noch keine Ziele für heute';
    } else if (open.isEmpty) {
      status = 'Alles erledigt 🎉';
    } else {
      status = '$done von $total erledigt';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: gold, size: 20),
              const SizedBox(width: 8),
              const Text('Heute',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(status,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 6,
                color: gold,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ],
          for (final g in open.take(3))
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => store.toggleDone(g),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.radio_button_unchecked,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(g.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ),
                  ],
                ),
              ),
            ),
          if (open.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text('+ ${open.length - 3} weitere',
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: Text(total == 0 ? 'Ziele festlegen' : 'Zu meinen Zielen',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
