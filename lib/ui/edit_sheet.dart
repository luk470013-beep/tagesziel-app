import 'package:flutter/material.dart';

import '../models.dart';
import '../notifications.dart';
import 'scope.dart';
import 'theme.dart';

/// Öffnet das Formular zum Anlegen oder Bearbeiten eines Eintrags.
Future<void> showEditSheet(
  BuildContext context, {
  Entry? entry,
  EntryType type = EntryType.idea,
  String? day,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => EditSheet(entry: entry, initialType: type, initialDay: day),
  );
}

class EditSheet extends StatefulWidget {
  const EditSheet({
    super.key,
    this.entry,
    required this.initialType,
    this.initialDay,
  });

  final Entry? entry;
  final EntryType initialType;
  final String? initialDay;

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  final TextEditingController _tagInput = TextEditingController();
  late EntryType _type;
  late List<String> _tags;
  late String _day;
  DateTime? _remindAt;
  Repeat _repeat = Repeat.none;

  bool get _isNew => widget.entry == null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _title = TextEditingController(text: e?.title ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _type = e?.type ?? widget.initialType;
    _tags = [...?e?.tags];
    _day = e?.day ?? widget.initialDay ?? dayKey(DateTime.now());
    _remindAt = e?.remindAt;
    _repeat = e?.repeat ?? Repeat.none;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  void _addTag(String raw) {
    for (final part in raw.split(RegExp(r'[,#\s]+'))) {
      final t = part.trim().toLowerCase();
      if (t.isNotEmpty && !_tags.contains(t)) _tags.add(t);
    }
    _tagInput.clear();
    setState(() {});
  }

  Future<void> _pickDay() async {
    final current = parseDayKey(_day);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _day = dayKey(picked));
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    var base = _remindAt;
    if (base == null) {
      base = _type == EntryType.goal ? parseDayKey(_day) : now;
      base = DateTime(base.year, base.month, base.day, now.hour + 1);
    }
    DateTime date = base;
    if (_repeat != Repeat.daily) {
      final d = await showDatePicker(
        context: context,
        initialDate: base.isBefore(DateTime(now.year, now.month, now.day))
            ? now
            : base,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: DateTime(2100),
        helpText: 'Erinnerung – Datum',
      );
      if (d == null || !mounted) return;
      date = d;
    }
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour % 24, minute: base.minute),
      helpText: 'Erinnerung – Uhrzeit',
    );
    if (t == null || !mounted) return;
    setState(() {
      _remindAt = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    });
    final ok = await Notifications.instance.ensurePermission();
    if (!ok && Notifications.instance.supported && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Benachrichtigungen sind aus. Erlaube sie in den Android-Einstellungen.'),
      ));
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gib einen Titel ein.')),
      );
      return;
    }
    if (_tagInput.text.trim().isNotEmpty) _addTag(_tagInput.text);
    final store = StoreScope.read(context);
    final e = widget.entry;
    if (e == null) {
      store.add(
        type: _type,
        title: title,
        note: _note.text,
        tags: _tags,
        day: _type == EntryType.goal ? _day : null,
        remindAt: _remindAt,
        repeat: _repeat,
      );
    } else {
      e
        ..type = _type
        ..title = title
        ..note = _note.text.trim()
        ..tags = _tags
        ..day = _type == EntryType.goal ? _day : null
        ..remindAt = _remindAt
        ..repeat = _repeat;
      store.update(e);
    }
    Navigator.of(context).pop();
  }

  void _delete() {
    final e = widget.entry;
    if (e == null) return;
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    store.delete(e);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: Text('„${e.title}“ gelöscht'),
      action: SnackBarAction(
          label: 'Rückgängig', onPressed: () => store.restore(e)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final store = StoreScope.of(context);
    final suggestions =
        store.tagsOf(_type).where((t) => !_tags.contains(t)).take(8).toList();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  _isNew ? 'Neuer Eintrag' : 'Bearbeiten',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (!_isNew)
                  IconButton(
                    tooltip: 'Löschen',
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline, color: s.error),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<EntryType>(
              showSelectedIcon: false,
              segments: [
                for (final t in EntryType.values)
                  ButtonSegment(
                    value: t,
                    label: Text(t.label),
                    icon: Icon(typeIcon(t), size: 18),
                  ),
              ],
              selected: {_type},
              onSelectionChanged: (sel) => setState(() => _type = sel.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(hintText: 'Titel'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              minLines: 3,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notiz (optional)'),
            ),
            const SizedBox(height: 16),
            // ---------- Tags ----------
            Text('Tags', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _tags)
                  InputChip(
                    label: Text('#$t'),
                    onDeleted: () => setState(() => _tags.remove(t)),
                  ),
                for (final t in suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(t),
                    onPressed: () => setState(() => _tags.add(t)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tagInput,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Tag hinzufügen, z. B. trading',
                prefixIcon: const Icon(Icons.tag),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_tagInput.text),
                ),
              ),
              onSubmitted: _addTag,
            ),
            const SizedBox(height: 16),
            // ---------- Tag (nur Ziele) ----------
            if (_type == EntryType.goal)
              _OptionTile(
                icon: Icons.calendar_today_outlined,
                title: 'Für',
                value:
                    '${fmtRelativeDay(parseDayKey(_day))} · ${fmtDayLong(parseDayKey(_day))}',
                onTap: _pickDay,
              ),
            // ---------- Erinnerung ----------
            _OptionTile(
              icon: Icons.notifications_none,
              title: 'Erinnerung',
              value: _remindAt == null
                  ? 'Keine'
                  : fmtReminder(_remindAt!, _repeat),
              onTap: _pickReminder,
              trailing: _remindAt == null
                  ? null
                  : IconButton(
                      tooltip: 'Erinnerung entfernen',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _remindAt = null),
                    ),
            ),
            if (_remindAt != null) ...[
              const SizedBox(height: 8),
              SegmentedButton<Repeat>(
                showSelectedIcon: false,
                segments: [
                  for (final r in Repeat.values)
                    ButtonSegment(value: r, label: Text(r.label)),
                ],
                selected: {_repeat},
                onSelectionChanged: (sel) =>
                    setState(() => _repeat = sel.first),
              ),
            ],
            if (_remindAt != null && !Notifications.instance.supported) ...[
              const SizedBox(height: 8),
              Text(
                'Hinweis: In der Browser-Vorschau werden keine Erinnerungen '
                'verschickt – erst in der Android-App.',
                style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_isNew ? 'Hinzufügen' : 'Speichern',
                  style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: s.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
            child: Row(
              children: [
                Icon(icon, color: s.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 12, color: s.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(value, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: Center(
                    child: trailing ??
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.chevron_right, color: s.outline),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
