import 'package:flutter/material.dart';

import '../models.dart';
import 'edit_sheet.dart';
import 'scope.dart';
import 'widgets.dart';

/// Übersicht aller wiederkehrenden Ziele (z. B. "Montag: Arme trainieren").
class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.templates();
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wiederkehrende Ziele')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEditSheet(context,
            type: EntryType.goal, recurDays: [DateTime.now().weekday]),
        icon: const Icon(Icons.add),
        label: const Text('Neu'),
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.repeat,
              title: 'Noch keine wiederkehrenden Ziele',
              subtitle: 'Zum Beispiel „Arme trainieren“ jeden Montag. '
                  'Sie erscheinen automatisch an den gewählten Tagen.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // Wochenübersicht
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        for (var wd = 1; wd <= 7; wd++)
                          Expanded(
                            child: Column(
                              children: [
                                Text(weekdayShort[wd - 1],
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: wd == DateTime.now().weekday
                                            ? s.primary
                                            : s.onSurfaceVariant)),
                                const SizedBox(height: 6),
                                Text(
                                  '${items.where((t) => t.recurDays.contains(wd)).length}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final t in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SwipeToDelete(
                      entry: t,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(16, 6, 12, 6),
                          leading: Icon(Icons.repeat, color: s.primary),
                          title: Text(t.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(t.remindAt != null
                              ? '${fmtWeekdays(t.recurDays)} · Erinnerung ${fmtTime(t.remindAt!)}'
                              : fmtWeekdays(t.recurDays)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => showEditSheet(context, entry: t),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Nach links wischen beendet die Wiederholung.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: s.onSurfaceVariant),
                  ),
                ),
              ],
            ),
    );
  }
}
