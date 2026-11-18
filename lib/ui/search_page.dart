import 'package:flutter/material.dart';

import 'scope.dart';
import 'widgets.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final results = store.search(_q.text);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _q,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Alles durchsuchen …',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _q.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_q.clear),
                    ),
            ),
          ),
        ),
      ),
      body: _q.text.trim().isEmpty
          ? const EmptyState(
              icon: Icons.search,
              title: 'Suche in Zielen, Ideen und Infos',
              subtitle: 'Durchsucht Titel, Notizen und Tags.',
            )
          : results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off, title: 'Nichts gefunden')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      EntryCard(entry: results[i], showType: true),
                ),
    );
  }
}

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = StoreScope.of(context).withReminders();
    return Scaffold(
      appBar: AppBar(title: const Text('Erinnerungen')),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'Keine Erinnerungen',
              subtitle:
                  'Öffne einen Eintrag und tippe auf „Erinnerung“, um eine anzulegen.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => EntryCard(entry: items[i], showType: true),
            ),
    );
  }
}
