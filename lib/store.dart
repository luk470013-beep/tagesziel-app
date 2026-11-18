import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';
import 'quotes.dart';

/// Hält alle Einträge im Speicher und sichert sie lokal auf dem Gerät.
class Store extends ChangeNotifier {
  static const _kEntries = 'entries_v1';
  static const _kSettings = 'settings_v1';
  static const _kNextNid = 'next_nid_v1';
  static const _kLegacyBackground = 'img_background_v1';
  static const _kBgIds = 'img_bg_ids_v1';
  static const kImgAvatar = 'img_avatar_v1';
  static const _kQuotes = 'quotes_v1';

  late SharedPreferences _prefs;
  final List<Entry> _entries = [];
  Settings settings = Settings();
  int _nextNid = 1000;
  bool loaded = false;
  final Map<String, Uint8List?> _images = {};
  final List<Quote> _ownQuotes = [];
  final List<String> _bgIds = [];

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
    final q = _prefs.getString(_kQuotes);
    if (q != null) {
      try {
        _ownQuotes
          ..clear()
          ..addAll((jsonDecode(q) as List)
              .map((e) => Quote.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    _bgIds
      ..clear()
      ..addAll(_prefs.getStringList(_kBgIds) ?? const []);
    // Altes Einzelbild in die neue Bilderliste übernehmen.
    final legacy = _prefs.getString(_kLegacyBackground);
    if (legacy != null) {
      final id = _newId();
      await _prefs.setString('img_bg_$id', legacy);
      await _prefs.remove(_kLegacyBackground);
      _bgIds.add(id);
      await _prefs.setStringList(_kBgIds, _bgIds);
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
    _ensureRecurring(day);
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
      if (e.isTemplate) return false;
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

  // ---------- Wiederkehrende Ziele ----------

  List<Entry> templates() {
    final list = _entries.where((e) => e.isTemplate).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  Entry? templateOf(Entry e) {
    final id = e.templateId;
    if (id == null) return null;
    for (final t in _entries) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Legt für [day] die Ziele aus passenden Vorlagen an (falls noch nicht da).
  void _ensureRecurring(String day) {
    final wd = parseDayKey(day).weekday;
    final made = <Entry>[];
    for (final t in _entries) {
      if (!t.isTemplate || !t.recurDays.contains(wd)) continue;
      if (day.compareTo(dayKey(t.createdAt)) < 0) continue;
      if (t.skip.contains(day)) continue;
      if (_entries.any((e) => e.templateId == t.id && e.day == day)) continue;
      made.add(Entry(
        id: _newId(),
        nid: _nextNid++,
        type: EntryType.goal,
        title: t.title,
        note: t.note,
        tags: [...t.tags],
        createdAt: DateTime.now(),
        day: day,
        templateId: t.id,
      ));
    }
    if (made.isNotEmpty) {
      _entries.addAll(made);
      _save();
    }
  }

  Entry addTemplate({
    required String title,
    String note = '',
    List<String>? tags,
    required List<int> recurDays,
    DateTime? remindAt,
    DateTime? startDay,
  }) {
    final now = DateTime.now();
    final start = startDay != null && startDay.isBefore(now) ? startDay : now;
    final t = Entry(
      id: _newId(),
      nid: _nextNid++,
      type: EntryType.goal,
      title: title.trim(),
      note: note.trim(),
      tags: tags,
      createdAt: DateTime(start.year, start.month, start.day),
      recurDays: [...recurDays]..sort(),
      remindAt: remindAt,
    );
    _entries.add(t);
    _save();
    _notif.syncEntry(t);
    notifyListeners();
    return t;
  }

  /// Übernimmt Änderungen der Vorlage in alle offenen Ziele ab heute.
  void updateTemplate(Entry t) {
    t.updatedAt = DateTime.now();
    final today = dayKey(DateTime.now());
    _entries.removeWhere((e) =>
        e.templateId == t.id &&
        !e.done &&
        e.day != null &&
        e.day!.compareTo(today) > 0 &&
        !t.recurDays.contains(parseDayKey(e.day!).weekday));
    for (final e in _entries) {
      if (e.templateId == t.id &&
          !e.done &&
          e.day != null &&
          e.day!.compareTo(today) >= 0) {
        e
          ..title = t.title
          ..note = t.note
          ..tags = [...t.tags];
      }
    }
    _save();
    _notif.syncEntry(t);
    notifyListeners();
  }

  /// Beendet die Wiederholung. Offene künftige Ziele verschwinden,
  /// erledigte und vergangene bleiben als normale Ziele erhalten.
  void deleteTemplate(Entry t) {
    final today = dayKey(DateTime.now());
    _entries.removeWhere((e) =>
        e.templateId == t.id &&
        !e.done &&
        e.day != null &&
        e.day!.compareTo(today) > 0);
    for (final e in _entries) {
      if (e.templateId == t.id) e.templateId = null;
    }
    _entries.removeWhere((e) => e.id == t.id);
    _save();
    _notif.cancelEntry(t);
    notifyListeners();
  }

  /// Entfernt ein wiederkehrendes Ziel nur für diesen einen Tag.
  void skipInstance(Entry e) {
    final t = templateOf(e);
    if (t != null && e.day != null && !t.skip.contains(e.day)) {
      t.skip.add(e.day!);
    }
    delete(e);
  }

  /// Macht [skipInstance] rückgängig.
  void unskipInstance(Entry e) {
    final t = templateOf(e);
    if (t != null) t.skip.remove(e.day);
    restore(e);
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
      if (e.recurDays.isEmpty) e.day ??= dayKey(DateTime.now());
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
    _detachFromTemplate(e);
    e.day = day;
    update(e);
  }

  /// Löst ein wiederkehrendes Ziel von seiner Vorlage (z. B. beim
  /// Verschieben), damit es an seinem Tag nicht neu angelegt wird.
  void _detachFromTemplate(Entry e) {
    final t = templateOf(e);
    if (t != null && e.day != null && !t.skip.contains(e.day)) {
      t.skip.add(e.day!);
    }
    e.templateId = null;
  }

  /// Wandelt ein Ziel in eine Idee um.
  void goalToIdea(Entry e) {
    _detachFromTemplate(e);
    e.type = EntryType.idea;
    update(e);
  }

  /// Unerledigte Ziele aus vergangenen Tagen auf heute übernehmen.
  int carryOver() {
    final today = dayKey(DateTime.now());
    var n = 0;
    for (final e in _entries) {
      if (e.type == EntryType.goal &&
          !e.done &&
          e.templateId == null &&
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

  /// Speichert ein Bild. Gibt false zurück, wenn der Speicher voll ist.
  Future<bool> setImage(String key, Uint8List? bytes) async {
    try {
      if (bytes == null) {
        await _prefs.remove(key);
      } else {
        await _prefs.setString(key, base64Encode(bytes));
      }
    } catch (e) {
      debugPrint('Bild konnte nicht gespeichert werden: $e');
      return false;
    }
    _images[key] = bytes;
    notifyListeners();
    return true;
  }

  // Eigene Hintergrundbilder (wechseln täglich)
  List<String> get backgroundIds => List.unmodifiable(_bgIds);

  Uint8List? backgroundImage(String id) => image('img_bg_$id');

  Future<bool> addBackground(Uint8List bytes) async {
    final id = _newId();
    final ok = await setImage('img_bg_$id', bytes);
    if (!ok) return false;
    _bgIds.add(id);
    await _prefs.setStringList(_kBgIds, _bgIds);
    notifyListeners();
    return true;
  }

  Future<void> removeBackground(String id) async {
    _bgIds.remove(id);
    await _prefs.setStringList(_kBgIds, _bgIds);
    await setImage('img_bg_$id', null);
    if (_bgIds.isEmpty && settings.bgMode == BgMode.own) {
      updateSettings((s) => s.bgMode = BgMode.anime);
    }
    notifyListeners();
  }

  // ---------- Sprüche ----------

  List<Quote> get ownQuotes => List.unmodifiable(_ownQuotes);

  /// Alle Sprüche, die auf der Startseite rotieren.
  List<Quote> quotePool() {
    final builtIn = [
      for (var i = 0; i < builtInQuotes.length; i++)
        Quote(id: 'builtin-$i', text: builtInQuotes[i]),
    ];
    if (_ownQuotes.isEmpty) return builtIn;
    if (settings.onlyOwnQuotes) return List.of(_ownQuotes);
    // Eigene Sprüche kommen doppelt so oft dran.
    final pool = <Quote>[];
    var b = 0;
    for (var round = 0; b < builtIn.length; round++) {
      pool.add(_ownQuotes[(2 * round) % _ownQuotes.length]);
      pool.add(_ownQuotes[(2 * round + 1) % _ownQuotes.length]);
      pool.add(builtIn[b++]);
    }
    return pool;
  }

  Future<void> _saveQuotes() => _prefs.setString(
      _kQuotes, jsonEncode(_ownQuotes.map((q) => q.toJson()).toList()));

  void addQuote(String text, String source) {
    _ownQuotes.add(Quote(id: _newId(), text: text.trim(), source: source.trim()));
    _saveQuotes();
    notifyListeners();
  }

  void updateQuote(Quote q, String text, String source) {
    q
      ..text = text.trim()
      ..source = source.trim();
    _saveQuotes();
    notifyListeners();
  }

  void deleteQuote(Quote q) {
    _ownQuotes.removeWhere((x) => x.id == q.id);
    _saveQuotes();
    notifyListeners();
  }

  void restoreQuote(Quote q, int index) {
    _ownQuotes.insert(index.clamp(0, _ownQuotes.length), q);
    _saveQuotes();
    notifyListeners();
  }

  // ---------- Backup ----------

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'tagesziele',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'entries': _entries.map((e) => e.toJson()).toList(),
        'quotes': _ownQuotes.map((q) => q.toJson()).toList(),
      });

  /// Importiert ein Backup. Vorhandene Einträge mit gleicher ID werden
  /// überschrieben, andere bleiben erhalten. Gibt die Anzahl zurück.
  Future<int> importJson(String raw) async {
    final data = jsonDecode(raw);
    final list = data is Map ? data['entries'] as List : data as List;
    if (data is Map && data['quotes'] is List) {
      for (final item in data['quotes'] as List) {
        final q = Quote.fromJson(Map<String, dynamic>.from(item as Map));
        _ownQuotes.removeWhere((x) => x.id == q.id);
        _ownQuotes.add(q);
      }
      await _saveQuotes();
    }
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
