import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';

/// Hält alle Einträge im Speicher und sichert sie lokal auf dem Gerät.
class Store extends ChangeNotifier {
  static const _kEntries = 'entries_v1';
  static const _kSettings = 'settings_v1';
  static const _kNextNid = 'next_nid_v1';
  static const kImgBackground = 'img_background_v1';
  static const kImgAvatar = 'img_avatar_v1';

  late SharedPreferences _prefs;
  final List<Entry> _entries = [];
  Settings settings = Settings();
  int _nextNid = 1000;
  bool loaded = false;
  final Map<String, Uint8List?> _images = {};

  /// Wie viele Ziele beim letzten Start übernommen wurden (für Hinweis).
  int lastCarried = 0;

  Notifications get _notif => Notifications.instance;

  List<Entry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_kEntries);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _entries
          ..clear()
          ..addAll(list.map((e) => Entry.fromJson(e as Map<String, dynamic>)));
      } catch (e) {
        debugPrint('Konnte Einträge nicht laden: $e');
      }
    }
    final s = _prefs.getString(_kSettings);
    if (s != null) {
      try {
        settings = Settings.fromJson(jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {}
    }
    _nextNid = _prefs.getInt(_kNextNid) ?? 1000;
    for (final e in _entries) {
      if (e.nid >= _nextNid) _nextNid = e.nid + 1;
    }
    loaded = true;
    if (settings.carryOver) lastCarried = carryOver();
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs.setString(
        _kEntries, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    await _prefs.setInt(_kNextNid, _nextNid);
  }

  Future<void> _saveSettings() async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  String _newId() {
    final r = Random();
    return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '${r.nextInt(1 << 20).toRadixString(36)}';
  }

  // ---------- Abfragen ----------

  List<Entry> goalsFor(String day) {
    final list =
        _entries.where((e) => e.type == EntryType.goal && e.day == day).toList();
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
    return list;
  }

  List<Entry> ofType(EntryType type, {String? tag}) {
    final list = _entries
        .where((e) => e.type == type && (tag == null || e.tags.contains(tag)))
        .toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  List<String> tagsOf(EntryType type) {
    final counts = <String, int>{};
    for (final e in _entries.where((e) => e.type == type)) {
      for (final t in e.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final tags = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return tags;
  }

  List<Entry> withReminders() {
    final list = _entries
        .where((e) =>
            e.hasReminder && !(e.type == EntryType.goal && e.done))
        .toList();
    list.sort((a, b) => a.remindAt!.compareTo(b.remindAt!));
    return list;
  }

  List<Entry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final terms = q.split(RegExp(r'\s+'));
    final list = _entries.where((e) {
      final hay =
          '${e.title}\n${e.note}\n${e.tags.join(' ')}'.toLowerCase();
      return terms.every(hay.contains);
    }).toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Statistik für einen Tag: (erledigt, gesamt)
  (int, int) progress(String day) {
    final g = goalsFor(day);
    return (g.where((e) => e.done).length, g.length);
  }

  // ---------- Änderungen ----------

  Entry add({
    required EntryType type,
    required String title,
    String note = '',
    List<String>? tags,
    String? day,
    DateTime? remindAt,
    Repeat repeat = Repeat.none,
  }) {
    final now = DateTime.now();
    final e = Entry(
      id: _newId(),
      nid: _nextNid++,
      type: type,
      title: title.trim(),
      note: note.trim(),
      tags: tags,
      createdAt: now,
      day: type == EntryType.goal ? (day ?? dayKey(now)) : null,
      remindAt: remindAt,
      repeat: repeat,
    );
    _entries.add(e);
    _save();
    if (e.hasReminder) _notif.syncEntry(e);
    notifyListeners();
    return e;
  }

  void update(Entry e) {
    e.updatedAt = DateTime.now();
    if (e.type == EntryType.goal) {
      e.day ??= dayKey(DateTime.now());
    } else {
      e.day = null;
      e.done = false;
    }
    _save();
    _notif.syncEntry(e);
    notifyListeners();
  }

  void toggleDone(Entry e) {
    e.done = !e.done;
    e.doneAt = e.done ? DateTime.now() : null;
    _save();
    if (e.hasReminder) _notif.syncEntry(e);
    notifyListeners();
  }

  void togglePin(Entry e) {
    e.pinned = !e.pinned;
    _save();
    notifyListeners();
  }

  void delete(Entry e) {
    _entries.removeWhere((x) => x.id == e.id);
    _save();
    _notif.cancelEntry(e);
    notifyListeners();
  }

  /// Fügt einen gelöschten Eintrag wieder ein (Rückgängig).
  void restore(Entry e) {
    if (_entries.any((x) => x.id == e.id)) return;
    _entries.add(e);
    _save();
    if (e.hasReminder) _notif.syncEntry(e);
    notifyListeners();
  }

  /// Verschiebt ein Tagesziel auf einen anderen Tag.
  void moveGoal(Entry e, String day) {
    e.day = day;
    update(e);
  }

  /// Unerledigte Ziele aus vergangenen Tagen auf heute übernehmen.
  int carryOver() {
    final today = dayKey(DateTime.now());
    var n = 0;
    for (final e in _entries) {
      if (e.type == EntryType.goal &&
          !e.done &&
          e.day != null &&
          e.day!.compareTo(today) < 0) {
        e.day = today;
        e.carried += 1;
        n++;
      }
    }
    if (n > 0) {
      _save();
      notifyListeners();
    }
    return n;
  }

  void updateSettings(void Function(Settings s) change) {
    change(settings);
    _saveSettings();
    _notif.syncMorning(settings);
    notifyListeners();
  }

  // ---------- Bilder (Startseite) ----------

  /// Eigenes Bild (Hintergrund oder Vordergrund) oder null.
  Uint8List? image(String key) {
    if (_images.containsKey(key)) return _images[key];
    final raw = _prefs.getString(key);
    Uint8List? bytes;
    if (raw != null) {
      try {
        bytes = base64Decode(raw);
      } catch (_) {}
    }
    _images[key] = bytes;
    return bytes;
  }

  Future<void> setImage(String key, Uint8List? bytes) async {
    _images[key] = bytes;
    notifyListeners();
    if (bytes == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, base64Encode(bytes));
    }
  }

  // ---------- Backup ----------

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'tagesziele',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'entries': _entries.map((e) => e.toJson()).toList(),
      });

  /// Importiert ein Backup. Vorhandene Einträge mit gleicher ID werden
  /// überschrieben, andere bleiben erhalten. Gibt die Anzahl zurück.
  Future<int> importJson(String raw) async {
    final data = jsonDecode(raw);
    final list = data is Map ? data['entries'] as List : data as List;
    var n = 0;
    for (final item in list) {
      final e = Entry.fromJson(Map<String, dynamic>.from(item as Map));
      _entries.removeWhere((x) => x.id == e.id);
      final fixed = Entry.fromJson({...e.toJson(), 'nid': _nextNid++});
      _entries.add(fixed);
      n++;
    }
    await _save();
    await _notif.resyncAll(_entries, settings);
    notifyListeners();
    return n;
  }
}
