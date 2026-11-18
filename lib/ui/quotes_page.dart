import 'package:flutter/material.dart';

import '../models.dart';
import 'scope.dart';
import 'widgets.dart';

/// Eigene Sprüche verwalten (z. B. Lieblingszitate aus Animes).
class QuotesPage extends StatelessWidget {
  const QuotesPage({super.key});

  Future<void> _edit(BuildContext context, [Quote? quote]) async {
    final store = StoreScope.read(context);
    final text = TextEditingController(text: quote?.text ?? '');
    final source = TextEditingController(text: quote?.source ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(quote == null ? 'Neuer Spruch' : 'Spruch bearbeiten'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: text,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Spruch'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: source,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Quelle (optional), z. B. Naruto'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Speichern')),
        ],
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty) {
      if (quote == null) {
        store.addQuote(text.text, source.text);
      } else {
        store.updateQuote(quote, text.text, source.text);
      }
    }
    text.dispose();
    source.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final quotes = store.ownQuotes;
    final s = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sprüche')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Spruch'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Text(
            'Trag hier deine Lieblingssprüche ein, zum Beispiel aus Animes. '
            'Auf der Startseite wechseln sie sich mit den eingebauten ab – '
            'deine eigenen kommen dabei häufiger dran.\n'
            'Tipp: Auf der Startseite den Spruch antippen = nächster Spruch.',
            style: TextStyle(color: s.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nur meine eigenen Sprüche zeigen'),
            subtitle: quotes.isEmpty
                ? const Text('Wirkt, sobald du einen eigenen Spruch hast')
                : null,
            value: store.settings.onlyOwnQuotes,
            onChanged: (v) => store.updateSettings((x) => x.onlyOwnQuotes = v),
          ),
          const SizedBox(height: 8),
          if (quotes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.format_quote,
                title: 'Noch keine eigenen Sprüche',
                subtitle: 'Tippe auf „+ Spruch“.',
              ),
            ),
          for (final (i, q) in quotes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey('quote-${q.id}'),
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
                  final messenger = ScaffoldMessenger.of(context);
                  store.deleteQuote(q);
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: const Text('Spruch gelöscht'),
                      action: SnackBarAction(
                          label: 'Rückgängig',
                          onPressed: () => store.restoreQuote(q, i)),
                    ));
                },
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _edit(context, q),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('„${q.text}“',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontStyle: FontStyle.italic,
                                  height: 1.35)),
                          if (q.source.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('— ${q.source}',
                                style: TextStyle(color: s.primary)),
                          ],
                        ],
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
