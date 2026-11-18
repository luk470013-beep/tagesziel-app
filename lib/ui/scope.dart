import 'package:flutter/widgets.dart';

import '../store.dart';

/// Stellt den [Store] im ganzen Widget-Baum bereit.
class StoreScope extends InheritedNotifier<Store> {
  const StoreScope({super.key, required Store store, required super.child})
      : super(notifier: store);

  /// Zugriff mit automatischem Neuaufbau bei Änderungen.
  static Store of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Zugriff ohne Neuaufbau (z. B. in Callbacks).
  static Store read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
