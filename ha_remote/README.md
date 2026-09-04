# HA Remote – Home Assistant Add-on

Installiere dieses Verzeichnis als **lokales Add-on-Repository** in Home Assistant
(Einstellungen → Add-ons → Add-on-Store → ⋮ → Repository) und wähle den Ordner
`addons` dieses Repos bzw. die Git-URL, die auf `addons/` zeigt.

Lokale Entwicklung (Supervisor „Local add-ons“):

1. Repo nach `/addons` auf dem HA-Host kopieren oder als Git-Repo einbinden:
   - Repository-URL = Root dieses Projekts, Add-on liegt unter `addons/ha_remote`
2. Oder: Inhalt von `addons/ha_remote` nach `/addons/ha_remote` auf dem HA-Host legen
   und `repository.yaml` nach `/addons/repository.yaml`

Siehe `DOCS.md` für Nutzer-Anleitung und `docs/PHASE3.md` im Repo-Root.
