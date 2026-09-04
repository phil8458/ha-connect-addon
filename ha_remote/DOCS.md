# HA Remote

Remote-Zugang zu Home Assistant **ohne Portfreigabe** am Router.

## Einrichtung

1. Account auf deinem HA-Remote-Dashboard anlegen und Instanz/Subdomain erstellen.
2. **Pairing-Code** erzeugen (5 Minuten gültig).
3. Dieses Add-on installieren und starten.
4. In den Add-on-Optionen:
   - **api_base**: URL deiner HA-Remote-API (z. B. `https://ha-remote.com` oder die LAN-IP deines Dev-PCs)
   - **pairing_code**: den 6-stelligen Code
5. Add-on neu starten.
6. Status sollte `online` werden; die Companion-App nutzt die gesetzte externe URL.

## Optionen

| Option | Bedeutung |
|--------|-----------|
| `api_base` | Basis-URL der HA-Remote-API |
| `pairing_code` | 6-stelliger Code (nur beim ersten Pair / nach Reset) |
| `local_host` | Ziel im Heimnetz (`homeassistant` unter HA OS) |
| `local_port` | Port von Home Assistant (Standard 8123) |
| `heartbeat_interval` | Sekunden zwischen Heartbeats |
| `set_external_url` | Externe URL in HA automatisch setzen |
| `reset_pairing` | Gespeichertes Token löschen und neu pairen |

Nach erfolgreichem Pairing kannst du `pairing_code` leeren. Das Token bleibt unter `/data` gespeichert.

## Neu pairen

1. `reset_pairing: true` setzen und speichern
2. Neuen Code eintragen
3. Add-on neu starten
4. `reset_pairing` wieder auf `false`

## Logs

In den Logs siehst du den Verbindungsstatus. Secrets (Tokens) werden nicht ausgegeben.
