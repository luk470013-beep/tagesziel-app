import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notifications.dart';
import 'store.dart';
import 'ui/home.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await Notifications.instance.init();
  await store.load();
  // Morgen-Erinnerung bei jedem Start neu planen (falls aktiviert).
  Notifications.instance.syncMorning(store.settings);
  runApp(TageszieleApp(store: store));
}

class TageszieleApp extends StatelessWidget {
  const TageszieleApp({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Tagesziele',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        locale: const Locale('de', 'DE'),
        supportedLocales: const [Locale('de', 'DE')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomePage(),
      ),
    );
  }
}
