import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../notifications.dart';
import 'quotes_page.dart';
import 'scope.dart';
import 'start_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _pickMorningTime(BuildContext context) async {
    final store = StoreScope.read(context);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: store.settings.morningHour,
          minute: store.settings.morningMinute),
    );
    if (t == null) return;
    store.updateSettings((s) {
      s.morningHour = t.hour;
      s.morningMinute = t.minute;
    });
  }

  Future<void> _toggleMorning(BuildContext context, bool on) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      final ok = await Notifications.instance.ensurePermission();
      if (!ok && Notifications.instance.supported) {
        messenger.showSnackBar(const SnackBar(
            content: Text(
                'Benachrichtigungen sind aus. Erlaube sie in den Android-Einstellungen.')));
      }
    }
    store.updateSettings((s) => s.morningEnabled = on);
  }

  Future<void> _editName(BuildContext context) async {
    final store = StoreScope.read(context);
    final controller = TextEditingController(text: store.settings.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dein Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'z. B. Luca'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Speichern')),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    store.updateSettings((s) => s.name = name.trim());
  }

  Future<void> _export(BuildContext context) async {
    final json = StoreScope.read(context).exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup kopiert'),
        content: const Text(
            'Alle Einträge wurden in die Zwischenablage kopiert. Füge sie z. B. '
            'in eine Notiz, eine Mail an dich selbst oder in Google Drive ein.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trimLeft().startsWith('{')) {
      controller.text = clip.text!;
    }
    if (!context.mounted) return;
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup einfügen'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            maxLines: 8,
            decoration:
                const InputDecoration(hintText: 'Backup-Text hier einfügen'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Importieren')),
        ],
      ),
    );
    controller.dispose();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final n = await store.importJson(raw);
      messenger.showSnackBar(SnackBar(content: Text('$n Einträge importiert')));
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Das Backup konnte nicht gelesen werden.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final st = store.settings;
    final s = Theme.of(context).colorScheme;
    final supported = Notifications.instance.supported;

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
          child: Text(t,
              style: TextStyle(
                  color: s.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          header('Startseite'),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Name für die Begrüßung'),
            subtitle: Text(st.name.isEmpty ? 'Nicht gesetzt' : st.name),
            onTap: () => _editName(context),
          ),
          ListTile(
            leading: const Icon(Icons.wallpaper),
            title: const Text('Hintergrund'),
            subtitle: Text(switch (st.bgMode) {
              BgMode.anime => 'Anime-Stadt',
              BgMode.photo => 'Fotos',
              BgMode.own => 'Meine Bilder',
            }),
            onTap: () => showBackgroundOptions(context),
          ),
          ListTile(
            leading: const Icon(Icons.format_quote),
            title: const Text('Sprüche'),
            subtitle: Text(store.ownQuotes.isEmpty
                ? 'Eigene Sprüche hinzufügen'
                : '${store.ownQuotes.length} eigene Sprüche'),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const QuotesPage())),
          ),
          header('Tagesziele'),
          SwitchListTile(
            title: const Text('Offene Ziele übernehmen'),
            subtitle: const Text(
                'Nicht erledigte Ziele wandern automatisch in den nächsten Tag.'),
            value: st.carryOver,
            onChanged: (v) {
              store.updateSettings((s) => s.carryOver = v);
              if (v) store.carryOver();
            },
          ),
          SwitchListTile(
            title: const Text('Morgen-Erinnerung'),
            subtitle: Text(supported
                ? 'Jeden Tag ein Hinweis: „Setz dir deine Tagesziele“.'
                : 'Nur in der Android-App verfügbar.'),
            value: st.morningEnabled,
            onChanged: (v) => _toggleMorning(context, v),
          ),
          ListTile(
            enabled: st.morningEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Uhrzeit'),
            trailing: Text(fmtTimeOfDay(st.morningHour, st.morningMinute),
                style: const TextStyle(fontSize: 16)),
            onTap: () => _pickMorningTime(context),
          ),
          header('Daten'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Backup kopieren'),
            subtitle: const Text('Alle Einträge als Text in die Zwischenablage'),
            onTap: () => _export(context),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Backup einfügen'),
            subtitle: const Text('Einträge aus einem Backup wiederherstellen'),
            onTap: () => _import(context),
          ),
          header('Info'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tagesziele'),
            subtitle: Text(
                '${store.entries.length} Einträge · Daten bleiben nur auf diesem Gerät'),
          ),
          if (!supported)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Text(
                'Du siehst gerade die Browser-Vorschau. Einträge werden hier nur '
                'in diesem Browser gespeichert, Erinnerungen gibt es erst in der '
                'Android-App.',
                style: TextStyle(color: s.onSurfaceVariant, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
