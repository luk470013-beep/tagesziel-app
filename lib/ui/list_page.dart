import 'package:flutter/material.dart';

import '../models.dart';
import 'scope.dart';
import 'theme.dart';
import 'widgets.dart';

/// Liste für Ideen bzw. Infos, mit Tag-Filter.
class EntryListPage extends StatefulWidget {
  const EntryListPage({super.key, required this.type});

  final EntryType type;

  @override
  State<EntryListPage> createState() => _EntryListPageState();
}

class _EntryListPageState extends State<EntryListPage> {
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tags = store.tagsOf(widget.type);
    if (_tag != null && !tags.contains(_tag)) _tag = null;
    final items = store.ofType(widget.type, tag: _tag);

    return Column(
      children: [
        if (tags.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('Alle'),
                    selected: _tag == null,
                    onSelected: (_) => setState(() => _tag = null),
                  ),
                ),
                for (final t in tags)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('#$t'),
                      selected: _tag == t,
                      onSelected: (sel) =>
                          setState(() => _tag = sel ? t : null),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: typeIcon(widget.type),
                  title: widget.type == EntryType.idea
                      ? 'Noch keine Ideen'
                      : 'Noch keine Infos',
                  subtitle: widget.type == EntryType.idea
                      ? 'Halte jeden Gedanken fest – tippe auf +.'
                      : 'Speichere hier alles, was du später brauchst.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => SwipeToDelete(
                    entry: items[i],
                    child: EntryCard(entry: items[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
