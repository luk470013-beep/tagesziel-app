import 'package:flutter/material.dart';

import '../models.dart';
import 'edit_sheet.dart';
import 'scope.dart';
import 'theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: s.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: s.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kleines Info-Etikett (Erinnerung, Tag, übernommen …).
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = color ?? s.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: c, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Löschen per Wischen, mit "Rückgängig".
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({super.key, required this.entry, required this.child});

  final Entry entry;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${entry.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: s.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: s.onErrorContainer),
      ),
      onDismissed: (_) {
        final store = StoreScope.read(context);
        final messenger = ScaffoldMessenger.of(context);
        store.delete(entry);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('„${entry.title}“ gelöscht'),
            action: SnackBarAction(
              label: 'Rückgängig',
              onPressed: () => store.restore(entry),
            ),
          ));
      },
      child: child,
    );
  }
}

/// Karte für Ideen, Infos und Suchergebnisse.
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.entry, this.showType = false});

  final Entry entry;
  final bool showType;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final e = entry;
    final pills = <Widget>[
      if (showType)
        Pill(
            label: e.type == EntryType.goal && e.day != null
                ? 'Ziel · ${fmtRelativeDay(parseDayKey(e.day!))}'
                : e.type.label,
            icon: typeIcon(e.type),
            color: typeColor(context, e.type)),
      if (e.remindAt != null)
        Pill(
            label: fmtReminder(e.remindAt!, e.repeat),
            icon: Icons.notifications_none,
            color: s.primary),
      for (final t in e.tags) Pill(label: '#$t'),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showEditSheet(context, entry: e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: e.type == EntryType.goal && e.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (e.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        e.note,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: s.onSurfaceVariant, height: 1.35),
                      ),
                    ],
                    if (pills.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: pills),
                    ],
                  ],
                ),
              ),
              if (e.type != EntryType.goal)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: e.pinned ? 'Lösen' : 'Anheften',
                  onPressed: () => StoreScope.read(context).togglePin(e),
                  icon: Icon(
                    e.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                    color: e.pinned ? s.primary : s.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
