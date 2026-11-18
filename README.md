# Tagesziele

Android-App für **Tagesziele, Ideen und Infos** – mit Erinnerungen.

- **Heute:** Tagesziele abhaken, Fortschritt sehen; Offenes wandert automatisch in den nächsten Tag
- **Ideen / Infos:** Notizen mit Tags, Anheften, Tag-Filter
- **Suche** über alles
- **Erinnerungen** pro Eintrag (einmalig, täglich, wöchentlich) + optionale Morgen-Erinnerung
- Daten bleiben lokal auf dem Gerät; Backup per Zwischenablage

## Vorschau & Download

- **Browser-Vorschau:** https://luk470013-beep.github.io/tagesziel-app/ (ohne Erinnerungen)
- **APK:** unter [Releases → app-latest](../../releases/tag/app-latest)

Bei jedem Push auf `main` baut GitHub Actions automatisch die Web-Vorschau und die APK
(`.github/workflows/build.yml`).

## Aufbau

```
lib/
  main.dart            Start, Theme, Sprache
  models.dart          Datenmodell + Datumsformatierung
  store.dart           Speicherung (shared_preferences), Übernahme, Suche, Backup
  notifications.dart   Erinnerungen (flutter_local_notifications)
  ui/                  Seiten: Heute, Ideen/Infos, Suche, Erinnerungen, Einstellungen
android_overrides/     Eigene Android-Einstellungen (Manifest, Gradle)
```

Die Ordner `android/` und `web/` werden beim Build mit `flutter create` erzeugt und dann mit
`android_overrides/` überschrieben. Lokal: `flutter create --platforms=android,web --org de.luca --project-name tagesziele . && cp -r android_overrides/. android/`
