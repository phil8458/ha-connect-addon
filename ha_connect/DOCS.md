# HA Connect

## So richtest du es ein

1. Öffne https://ha-connect.com und melde dich an.
2. Lege eine Instanz an und erzeuge einen **Pairing-Code**.
3. In Home Assistant bei dieser App den Tab **Konfiguration** öffnen.
4. Setze:
   - `api_base` = `https://ha-connect.com`
   - `pairing_code` = dein 6-stelliger Code
5. Speichern, dann die App **starten**.
6. Unter **Protokoll** den Status prüfen (`online` / `start proxy success`).

Keine `configuration.yaml`-Anpassung nötig.

Falls die Companion-App von unterwegs noch die lokale URL nutzt:
**Einstellungen → System → Netzwerk → Internet** auf
`https://DEIN-SLUG.ha-connect.com` prüfen (wird meist automatisch gesetzt).

## Optionen

| Option | Bedeutung |
|--------|-----------|
| `api_base` | URL der HA-Connect-Cloud |
| `pairing_code` | Code vom Dashboard (nur beim ersten Pair nötig) |
| `local_host` | Meist `homeassistant` |
| `local_port` | Meist `8123` |
| `set_external_url` | Externe URL in HA automatisch setzen |
| `reset_pairing` | Token löschen und neu pairen |

## Neu pairen

1. `reset_pairing` auf an
2. Neuen Code eintragen
3. Speichern und neu starten
4. `reset_pairing` wieder aus
