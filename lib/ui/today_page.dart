import 'package:flutter/material.dart';

import '../models.dart';
import 'edit_sheet.dart';
import 'scope.dart';
import 'widgets.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  DateTime _day = DateTime.now();
  final _input = TextEditingController();
  final _focus = FocusNode();

  String get _key => dayKey(_day);

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _shift(int days) =>
      setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _day = picked);
  }

  void _quickAdd() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    StoreScope.read(context)
        .add(type: EntryType.goal, title: text, day: _key);
    _input.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = Theme.of(context).colorScheme;
    final goals = store.goalsFor(_key);
    final (done, total) = store.progress(_key);
    final isToday = _key == dayKey(DateTime.now());

    return Column(
      children: [
        // ---------- Datum ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _pickDay,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(fmtRelativeDay(_day),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(fmtDayLong(_day),
                            style: TextStyle(
                                color: s.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        if (!isToday)
          TextButton.icon(
            onPressed: () => setState(() => _day = DateTime.now()),
            icon: const Icon(Icons.today, size: 18),
            label: const Text('Zu heute'),
          ),
        // ---------- Fortschritt ----------
        if (total > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      done == total
                          ? 'Alles erledigt 🎉'
                          : '$done von $total erledigt',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text('${(done * 100 / total).round()} %',
                        style: TextStyle(color: s.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: done / total,
                    minHeight: 8,
                    backgroundColor: s.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        // ---------- Schnell hinzufügen ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _input,
            focusNode: _focus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _quickAdd(),
            decoration: InputDecoration(
              hintText: 'Neues Ziel …',
              prefixIcon: const Icon(Icons.add_task),
              suffixIcon: IconButton(
                tooltip: 'Mit Details hinzufügen',
                icon: const Icon(Icons.tune),
                onPressed: () => showEditSheet(context,
                    type: EntryType.goal, day: _key),
              ),
            ),
          ),
        ),
        // ---------- Liste ----------
        Expanded(
          child: goals.isEmpty
              ? EmptyState(
                  icon: Icons.flag_outlined,
                  title: isToday
                      ? 'Noch keine Ziele für heute'
                      : 'Keine Ziele für diesen Tag',
                  subtitle: 'Tipp: Oben eintippen und Enter drücken.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: goals.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => SwipeToDelete(
                    entry: goals[i],
                    child: _GoalTile(goal: goals[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final Entry goal;

  void _menu(BuildContext context) async {
    final store = StoreScope.read(context);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Bearbeiten'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Auf heute verschieben'),
              onTap: () => Navigator.pop(ctx, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.next_plan_outlined),
              title: const Text('Auf morgen verschieben'),
              onTap: () => Navigator.pop(ctx, 'tomorrow'),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('In Ideen umwandeln'),
              onTap: () => Navigator.pop(ctx, 'idea'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        showEditSheet(context, entry: goal);
      case 'today':
        store.moveGoal(goal, dayKey(DateTime.now()));
      case 'tomorrow':
        store.moveGoal(goal, dayKey(tomorrow));
      case 'idea':
        store.goalToIdea(goal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final store = StoreScope.read(context);
    final g = goal;
    final tmpl = StoreScope.of(context).templateOf(g);
    final pills = <Widget>[
      if (tmpl != null)
        Pill(
            label: tmpl.remindAt != null
                ? '${fmtWeekdays(tmpl.recurDays)} · ${fmtTime(tmpl.remindAt!)}'
                : fmtWeekdays(tmpl.recurDays),
            icon: Icons.repeat,
            color: s.secondary),
      if (g.remindAt != null)
        Pill(
            label: fmtReminder(g.remindAt!, g.repeat),
            icon: Icons.notifications_none,
            color: s.primary),
      if (g.carried > 0 && !g.done)
        Pill(
            label: g.carried == 1 ? 'übernommen' : '${g.carried}× übernommen',
            icon: Icons.redo,
            color: s.tertiary),
      for (final t in g.tags) Pill(label: '#$t'),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showEditSheet(context, entry: g),
        onLongPress: () => _menu(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Row(
            children: [
              Transform.scale(
                scale: 1.2,
                child: Checkbox(
                  value: g.done,
                  shape: const CircleBorder(),
                  onChanged: (_) => store.toggleDone(g),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: g.done ? s.outline : s.onSurface,
                          decoration:
                              g.done ? TextDecoration.lineThrough : null,
                        ),
                        child: Text(g.title),
                      ),
                      if (g.note.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(g.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13, color: s.onSurfaceVariant)),
                      ],
                      if (pills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: pills),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mehr',
                onPressed: () => _menu(context),
                icon: Icon(Icons.more_vert, color: s.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
