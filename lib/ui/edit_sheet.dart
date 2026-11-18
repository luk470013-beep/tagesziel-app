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
  List<int>? recurDays,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => EditSheet(
      entry: entry,
      initialType: type,
      initialDay: day,
      initialRecur: recurDays,
    ),
  );
}

class EditSheet extends StatefulWidget {
  const EditSheet({
    super.key,
    this.entry,
    required this.initialType,
    this.initialDay,
    this.initialRecur,
  });

  final Entry? entry;
  final EntryType initialType;
  final String? initialDay;
  final List<int>? initialRecur;

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

  /// Wochentage für wiederkehrende Ziele (leer = einmalig).
  late List<int> _recur;

  /// Vorlage, falls ein wiederkehrendes Ziel bearbeitet wird.
  Entry? _template;

  bool get _isNew => widget.entry == null;
  bool get _recurring => _type == EntryType.goal && _recur.isNotEmpty;

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
    if (e != null && e.isTemplate) {
      _template = e;
    } else if (e?.templateId != null) {
      _template = StoreScope.read(context).templateOf(e!);
    }
    _recur = [...?(_template?.recurDays ?? widget.initialRecur)];
    if (_template != null) _remindAt = _template!.remindAt;
  }

  void _toggleDay(int wd) => setState(() {
        if (_recur.contains(wd)) {
          _recur.remove(wd);
        } else {
          _recur.add(wd);
        }
        _recur.sort();
      });

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
    if (_recurring) {
      final t = await showTimePicker(
        context: context,
        initialTime: _remindAt != null
            ? TimeOfDay(hour: _remindAt!.hour, minute: _remindAt!.minute)
            : TimeOfDay(hour: (now.hour + 1) % 24, minute: 0),
        helpText: 'Erinnerung – Uhrzeit',
      );
      if (t == null || !mounted) return;
      setState(() => _remindAt = DateTime(2000, 1, 3, t.hour, t.minute));
      await _checkPermission();
      return;
    }
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
    await _checkPermission();
  }

  Future<void> _checkPermission() async {
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
    final tmpl = _template;

    if (_recurring) {
      if (tmpl != null) {
        tmpl
          ..title = title
          ..note = _note.text.trim()
          ..tags = [..._tags]
          ..recurDays = [..._recur]
          ..remindAt = _remindAt;
        store.updateTemplate(tmpl);
        if (e != null && e != tmpl) {
          e
            ..title = title
            ..note = _note.text.trim()
            ..tags = [..._tags];
          store.update(e);
        }
      } else {
        final t = store.addTemplate(
          title: title,
          note: _note.text,
          tags: _tags,
          recurDays: _recur,
          remindAt: _remindAt,
          startDay: parseDayKey(_day),
        );
        if (e != null) {
          // Bestehender Eintrag wird zum ersten Ziel der Wiederholung.
          e
            ..type = EntryType.goal
            ..title = title
            ..note = _note.text.trim()
            ..tags = [..._tags]
            ..day = _day
            ..remindAt = null
            ..repeat = Repeat.none;
          if (_recur.contains(parseDayKey(_day).weekday)) e.templateId = t.id;
          store.update(e);
        }
      }
      Navigator.of(context).pop();
      return;
    }

    if (tmpl != null) {
      // Wiederholung wurde ausgeschaltet.
      store.deleteTemplate(tmpl);
      if (e == null || e == tmpl) {
        Navigator.of(context).pop();
        return;
      }
      e.templateId = null;
    }

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

  Future<void> _delete() async {
    final e = widget.entry;
    if (e == null) return;
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    final tmpl = _template;
    if (tmpl != null) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Wiederkehrendes Ziel'),
          content: Text(e == tmpl
              ? 'Wiederholung beenden? Offene Ziele ab morgen werden entfernt.'
              : 'Nur dieses Mal entfernen oder die Wiederholung ganz beenden?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen')),
            if (e != tmpl)
              TextButton(
                  onPressed: () => Navigator.pop(ctx, 'once'),
                  child: const Text('Nur dieses Mal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'all'),
                child: const Text('Wiederholung beenden')),
          ],
        ),
      );
      if (choice == null || !mounted) return;
      if (choice == 'once') {
        store.skipInstance(e);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(
          content: Text('„${e.title}“ für diesen Tag entfernt'),
          action: SnackBarAction(
              label: 'Rückgängig', onPressed: () => store.unskipInstance(e)),
        ));
      } else {
        store.deleteTemplate(tmpl);
        if (e != tmpl && !e.done) store.delete(e);
        Navigator.of(context).pop();
        messenger.showSnackBar(
            SnackBar(content: Text('Wiederholung von „${e.title}“ beendet')));
      }
      return;
    }
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
                  _template != null
                      ? 'Wiederkehrendes Ziel'
                      : (_isNew ? 'Neuer Eintrag' : 'Bearbeiten'),
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
            if (_template == null)
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
            // ---------- Wiederholen (nur Ziele) ----------
            if (_type == EntryType.goal) ...[
              Row(
                children: [
                  Icon(Icons.repeat, size: 18, color: s.primary),
                  const SizedBox(width: 8),
                  Text('Wiederholen',
                      style: Theme.of(context).textTheme.labelLarge),
                  const Spacer(),
                  Text(_recur.isEmpty ? 'Nie' : fmtWeekdays(_recur),
                      style: TextStyle(color: s.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var wd = 1; wd <= 7; wd++)
                    _DayChip(
                      label: weekdayShort[wd - 1],
                      selected: _recur.contains(wd),
                      onTap: () => _toggleDay(wd),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final preset in const [
                    ('Täglich', [1, 2, 3, 4, 5, 6, 7]),
                    ('Mo–Fr', [1, 2, 3, 4, 5]),
                    ('Wochenende', [6, 7]),
                  ])
                    ActionChip(
                      label: Text(preset.$1),
                      onPressed: () =>
                          setState(() => _recur = [...preset.$2]),
                    ),
                  if (_recur.isNotEmpty)
                    ActionChip(
                      label: const Text('Nie'),
                      onPressed: () => setState(() => _recur = []),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // ---------- Tag (nur einmalige Ziele) ----------
            if (_type == EntryType.goal && !_recurring)
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
                  : _recurring
                      ? '${fmtWeekdays(_recur)} um ${fmtTime(_remindAt!)}'
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
            if (_remindAt != null && !_recurring) ...[
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

class _DayChip extends StatelessWidget {
  const _DayChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? s.primary : s.surfaceContainerHigh,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? s.onPrimary : s.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
