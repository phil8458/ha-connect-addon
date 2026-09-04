# HA Remote – Home Assistant App (Add-on)

Öffentliches Repository für den Home-Assistant-App-Store.

Cloud/API-Code liegt **nicht** hier (privates Repo).  
Live-API: https://haremote.projex.ch

## Installation in Home Assistant

1. **Einstellungen → Apps → App-Store**
2. Rechts oben **⋮ → Repositories**
3. URL hinzufügen:

   ```text
   https://github.com/phil8458/ha-remote-addon
   ```

4. App **HA Remote** installieren (lädt vorgebautes Image von GHCR – kein lokaler Build auf dem Pi)
5. Optionen:
   - `api_base`: `https://haremote.projex.ch`
   - `pairing_code`: Code aus dem Dashboard (https://haremote.projex.ch)
6. Starten und Logs prüfen

Image: `ghcr.io/phil8458/ha-remote-addon` (amd64 / arm64 / armv7)

## Struktur

```
repository.yaml
ha_remote/
  config.yaml
  Dockerfile
  DOCS.md
  rootfs/...
```
