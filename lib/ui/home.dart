import 'package:flutter/material.dart';

import '../models.dart';
import 'edit_sheet.dart';
import 'list_page.dart';
import 'scope.dart';
import 'search_page.dart';
import 'settings_page.dart';
import 'today_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _tab = 0;
  String _lastDay = dayKey(DateTime.now());

  static const _titles = ['Heute', 'Ideen', 'Infos'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCarriedHint());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Wenn die App über Nacht offen war: beim Zurückkehren übernehmen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = dayKey(DateTime.now());
    if (today == _lastDay) return;
    _lastDay = today;
    final store = StoreScope.read(context);
    if (store.settings.carryOver) {
      store.lastCarried = store.carryOver();
      _showCarriedHint();
    }
  }

  void _showCarriedHint() {
    final store = StoreScope.read(context);
    final n = store.lastCarried;
    if (n <= 0 || !mounted) return;
    store.lastCarried = 0;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 1
          ? '1 offenes Ziel wurde auf heute übernommen'
          : '$n offene Ziele wurden auf heute übernommen'),
    ));
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final (done, total) = store.progress(dayKey(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Suchen',
            icon: const Icon(Icons.search),
            onPressed: () => _open(const SearchPage()),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _open(
                v == 'rem' ? const RemindersPage() : const SettingsPage()),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rem',
                child: ListTile(
                  leading: Icon(Icons.notifications_none),
                  title: Text('Erinnerungen'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'set',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Einstellungen'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          TodayPage(),
          EntryListPage(type: EntryType.idea),
          EntryListPage(type: EntryType.info),
        ],
      ),
      floatingActionButton: _tab == 0
          ? null
          : FloatingActionButton(
              tooltip: _tab == 1 ? 'Neue Idee' : 'Neue Info',
              onPressed: () => showEditSheet(context,
                  type: _tab == 1 ? EntryType.idea : EntryType.info),
              child: const Icon(Icons.add),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: total > 0 && done < total,
              label: Text('${total - done}'),
              child: const Icon(Icons.flag_outlined),
            ),
            selectedIcon: const Icon(Icons.flag),
            label: 'Heute',
          ),
          const NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Ideen',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Infos',
          ),
        ],
      ),
    );
  }
}
