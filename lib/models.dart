/// Datenmodell der App.
library;

enum EntryType { goal, idea, info }

extension EntryTypeLabel on EntryType {
  String get label => switch (this) {
        EntryType.goal => 'Tagesziel',
        EntryType.idea => 'Idee',
        EntryType.info => 'Info',
      };

  String get plural => switch (this) {
        EntryType.goal => 'Tagesziele',
        EntryType.idea => 'Ideen',
        EntryType.info => 'Infos',
      };
}

enum Repeat { none, daily, weekly }

extension RepeatLabel on Repeat {
  String get label => switch (this) {
        Repeat.none => 'Einmalig',
        Repeat.daily => 'Täglich',
        Repeat.weekly => 'Wöchentlich',
      };
}

class Entry {
  Entry({
    required this.id,
    required this.nid,
    required this.type,
    required this.title,
    this.note = '',
    List<String>? tags,
    required this.createdAt,
    DateTime? updatedAt,
    this.day,
    this.done = false,
    this.doneAt,
    this.carried = 0,
    this.pinned = false,
    this.remindAt,
    this.repeat = Repeat.none,
  })  : tags = tags ?? <String>[],
        updatedAt = updatedAt ?? createdAt;

  /// Eindeutige ID (String).
  final String id;

  /// Numerische ID für Benachrichtigungen (32 Bit).
  final int nid;

  EntryType type;
  String title;
  String note;
  List<String> tags;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Nur für Tagesziele: Tag im Format yyyy-MM-dd.
  String? day;
  bool done;
  DateTime? doneAt;

  /// Wie oft das Ziel schon in den nächsten Tag übernommen wurde.
  int carried;
  bool pinned;

  /// Erinnerungszeitpunkt (bei Wiederholung: erster Termin / Uhrzeit).
  DateTime? remindAt;
  Repeat repeat;

  bool get hasReminder => remindAt != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nid': nid,
        'type': type.name,
        'title': title,
        'note': note,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'day': day,
        'done': done,
        'doneAt': doneAt?.toIso8601String(),
        'carried': carried,
        'pinned': pinned,
        'remindAt': remindAt?.toIso8601String(),
        'repeat': repeat.name,
      };

  factory Entry.fromJson(Map<String, dynamic> j) {
    DateTime? d(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final created = d(j['createdAt']) ?? DateTime.now();
    return Entry(
      id: j['id'] as String,
      nid: (j['nid'] as num?)?.toInt() ?? 0,
      type: EntryType.values.firstWhere(
        (t) => t.name == j['type'],
        orElse: () => EntryType.info,
      ),
      title: (j['title'] as String?) ?? '',
      note: (j['note'] as String?) ?? '',
      tags: ((j['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      createdAt: created,
      updatedAt: d(j['updatedAt']) ?? created,
      day: j['day'] as String?,
      done: (j['done'] as bool?) ?? false,
      doneAt: d(j['doneAt']),
      carried: (j['carried'] as num?)?.toInt() ?? 0,
      pinned: (j['pinned'] as bool?) ?? false,
      remindAt: d(j['remindAt']),
      repeat: Repeat.values.firstWhere(
        (r) => r.name == j['repeat'],
        orElse: () => Repeat.none,
      ),
    );
  }
}

/// Ein Spruch (eingebaut oder selbst eingetragen).
class Quote {
  Quote({required this.id, required this.text, this.source = ''});

  final String id;
  String text;

  /// Woher der Spruch stammt, z. B. Anime oder Figur (optional).
  String source;

  bool get isOwn => !id.startsWith('builtin-');

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'source': source};

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        id: j['id'] as String,
        text: (j['text'] as String?) ?? '',
        source: (j['source'] as String?) ?? '',
      );
}

/// Hintergrund der Startseite.
enum BgMode { anime, photo, own }

class Settings {
  Settings({
    this.morningEnabled = false,
    this.morningHour = 8,
    this.morningMinute = 0,
    this.carryOver = true,
    this.name = '',
    this.bgMode = BgMode.anime,
    this.bgOffset = 0,
    this.onlyOwnQuotes = false,
  });

  bool morningEnabled;
  int morningHour;
  int morningMinute;
  bool carryOver;

  /// Name für die Begrüßung auf der Startseite.
  String name;

  /// Hintergrund der Startseite.
  BgMode bgMode;

  /// Verschiebt das tägliche Motiv ("Anderes Motiv").
  int bgOffset;

  /// Auf der Startseite nur eigene Sprüche zeigen.
  bool onlyOwnQuotes;

  Map<String, dynamic> toJson() => {
        'morningEnabled': morningEnabled,
        'morningHour': morningHour,
        'morningMinute': morningMinute,
        'carryOver': carryOver,
        'name': name,
        'bgMode': bgMode.name,
        'bgOffset': bgOffset,
        'onlyOwnQuotes': onlyOwnQuotes,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        morningEnabled: (j['morningEnabled'] as bool?) ?? false,
        morningHour: (j['morningHour'] as num?)?.toInt() ?? 8,
        morningMinute: (j['morningMinute'] as num?)?.toInt() ?? 0,
        carryOver: (j['carryOver'] as bool?) ?? true,
        name: (j['name'] as String?) ?? '',
        bgMode: BgMode.values.firstWhere(
          (m) => m.name == j['bgMode'],
          orElse: () => BgMode.anime,
        ),
        bgOffset: (j['bgOffset'] as num?)?.toInt() ?? 0,
        onlyOwnQuotes: (j['onlyOwnQuotes'] as bool?) ?? false,
      );
}

// ---------- Datums-Helfer (ohne intl) ----------

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${_2(d.month)}-${_2(d.day)}';

DateTime parseDayKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String _2(int v) => v.toString().padLeft(2, '0');

const _weekdays = [
  'Montag',
  'Dienstag',
  'Mittwoch',
  'Donnerstag',
  'Freitag',
  'Samstag',
  'Sonntag',
];
const _weekdaysShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const _months = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

String fmtTime(DateTime d) => '${_2(d.hour)}:${_2(d.minute)}';

String fmtTimeOfDay(int h, int m) => '${_2(h)}:${_2(m)}';

/// z. B. "Mittwoch, 18. November"
String fmtDayLong(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day}. ${_months[d.month - 1]}';

/// z. B. "18.11.2026"
String fmtDate(DateTime d) => '${_2(d.day)}.${_2(d.month)}.${d.year}';

/// Relativ: "Heute", "Gestern", "Morgen" oder Datum.
String fmtRelativeDay(DateTime d) {
  final today = DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(today.year, today.month, today.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Heute';
  if (diff == -1) return 'Gestern';
  if (diff == 1) return 'Morgen';
  return fmtDate(d);
}

String fmtReminder(DateTime d, Repeat r) => switch (r) {
      Repeat.none => '${fmtRelativeDay(d)}, ${fmtTime(d)}',
      Repeat.daily => 'Täglich ${fmtTime(d)}',
      Repeat.weekly => 'Jeden ${_weekdaysShort[d.weekday - 1]} ${fmtTime(d)}',
    };

/// Begrüßung je nach Tageszeit.
String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Gute Nacht';
  if (h < 11) return 'Guten Morgen';
  if (h < 14) return 'Guten Mittag';
  if (h < 18) return 'Guten Tag';
  return 'Guten Abend';
}

/// Tag im Jahr (1–366), z. B. für den Spruch des Tages.
int dayOfYear(DateTime d) =>
    DateTime(d.year, d.month, d.day).difference(DateTime(d.year)).inDays + 1;
