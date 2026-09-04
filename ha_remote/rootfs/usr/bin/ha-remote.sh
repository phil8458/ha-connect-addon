#!/usr/bin/env bash
set -euo pipefail

DATA_DIR="/data"
OPTIONS_FILE="/data/options.json"
TOKEN_FILE="${DATA_DIR}/device_token"
PAIR_FILE="${DATA_DIR}/pair.json"
FRPC_TOML="${DATA_DIR}/frpc.toml"
STATUS_FILE="${DATA_DIR}/status.json"
ADDON_VERSION="0.2.4"

log() {
  echo "[ha-remote] $*"
}

log_err() {
  echo "[ha-remote] ERROR: $*" >&2
}

redact() {
  sed -E \
    -e 's/("auth_token"[[:space:]]*:[[:space:]]*")[^"]+"/\1***"/g' \
    -e 's/("device_token"[[:space:]]*:[[:space:]]*")[^"]+"/\1***"/g' \
    -e 's/(auth\.token[[:space:]]*=[[:space:]]*")[^"]+"/\1***"/g'
}

read_options() {
  if [[ ! -f "${OPTIONS_FILE}" ]]; then
    log_err "options.json missing at ${OPTIONS_FILE}"
    exit 1
  fi
  API_BASE="$(jq -r '.api_base // "https://haremote.projex.ch"' "${OPTIONS_FILE}" | sed 's:/*$::')"
  PAIRING_CODE="$(jq -r '.pairing_code // empty' "${OPTIONS_FILE}")"
  LOCAL_HOST="$(jq -r '.local_host // "homeassistant"' "${OPTIONS_FILE}")"
  LOCAL_PORT="$(jq -r '.local_port // 8123' "${OPTIONS_FILE}")"
  HEARTBEAT_INTERVAL="$(jq -r '.heartbeat_interval // 30' "${OPTIONS_FILE}")"
  SET_EXTERNAL_URL="$(jq -r '.set_external_url // true' "${OPTIONS_FILE}")"
  RESET_PAIRING="$(jq -r '.reset_pairing // false' "${OPTIONS_FILE}")"
}

write_status() {
  local state="$1"
  local message="${2:-}"
  local public_url="${3:-}"
  jq -n \
    --arg state "$state" \
    --arg message "$message" \
    --arg public_url "$public_url" \
    --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{state:$state, message:$message, public_url:$public_url, updated:$updated}' \
    > "${STATUS_FILE}"
}

write_frpc_toml() {
  local proxy_name="$1"
  local subdomain="$2"
  local server_addr="$3"
  local server_port="$4"
  local auth_token="$5"

  cat > "${FRPC_TOML}" <<EOF
serverAddr = "${server_addr}"
serverPort = ${server_port}

auth.method = "token"
auth.token = "${auth_token}"

[[proxies]]
name = "${proxy_name}"
type = "http"
localIP = "${LOCAL_HOST}"
localPort = ${LOCAL_PORT}
subdomain = "${subdomain}"
EOF
  chmod 600 "${FRPC_TOML}"
}

do_pair() {
  local code="$1"
  if [[ -z "${code}" ]]; then
    log_err "Kein Pairing-Code gesetzt und kein gespeichertes Token. Bitte Code in den Add-on-Optionen eintragen."
    write_status "needs_pairing" "Pairing-Code fehlt"
    exit 1
  fi

  log "Pairing mit ${API_BASE} …"
  write_status "pairing" "Verbinde mit HA Remote"

  local tmp
  tmp="$(mktemp)"
  local http_code
  http_code="$(curl -sS -o "${tmp}" -w '%{http_code}' \
    -X POST "${API_BASE}/device/pair" \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg code "$code" '{code:$code}')" || true)"

  if [[ "${http_code}" != "200" ]]; then
    log_err "Pairing fehlgeschlagen (HTTP ${http_code}): $(cat "${tmp}" | redact)"
    write_status "error" "Pairing fehlgeschlagen (HTTP ${http_code})"
    rm -f "${tmp}"
    exit 1
  fi

  jq '.' "${tmp}" > "${PAIR_FILE}"
  jq -r '.device_token' "${tmp}" > "${TOKEN_FILE}"
  chmod 600 "${TOKEN_FILE}" "${PAIR_FILE}"

  local public_url proxy_name subdomain server_addr server_port auth_token
  public_url="$(jq -r '.public_url' "${tmp}")"
  proxy_name="$(jq -r '.tunnel.proxy_name' "${tmp}")"
  subdomain="$(jq -r '.tunnel.subdomain' "${tmp}")"
  server_addr="$(jq -r '.tunnel.server_addr' "${tmp}")"
  server_port="$(jq -r '.tunnel.server_port' "${tmp}")"
  auth_token="$(jq -r '.tunnel.auth_token' "${tmp}")"

  write_frpc_toml "${proxy_name}" "${subdomain}" "${server_addr}" "${server_port}" "${auth_token}"
  rm -f "${tmp}"

  log "Pairing OK – public_url=${public_url}"
  write_status "paired" "Pairing erfolgreich" "${public_url}"
}

set_ha_external_url() {
  local url="$1"
  if [[ "${SET_EXTERNAL_URL}" != "true" ]]; then
    log "Setzen der externen URL deaktiviert"
    return 0
  fi
  if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
    log "SUPERVISOR_TOKEN fehlt – externe URL bitte manuell setzen: ${url}"
    return 0
  fi

  log "Setze Home Assistant external_url …"
  # Core hat keinen REST-Endpunkt – nur WebSocket config/core/update
  local out
  if out="$(python3 /usr/bin/set-external-url.py "${url}" 2>&1)"; then
    log "external_url gesetzt (${out})"
    return 0
  fi
  log "WebSocket-Update fehlgeschlagen: ${out}"

  # Fallback: patch core.config (wirksam nach HA-Neustart)
  local storage=""
  for candidate in \
    "/homeassistant/.storage/core.config" \
    "/config/.storage/core.config"
  do
    if [[ -f "${candidate}" ]]; then
      storage="${candidate}"
      break
    fi
  done

  if [[ -n "${storage}" ]]; then
    if jq --arg url "$url" '.data.external_url = $url' "${storage}" > "${storage}.tmp" \
      && mv "${storage}.tmp" "${storage}"; then
      log "external_url in ${storage} geschrieben (Fallback)"
      log "Home Assistant einmal neu starten, damit Companion die URL übernimmt."
      return 0
    fi
  fi

  log_err "external_url konnte nicht automatisch gesetzt werden"
  log "Bitte unter Einstellungen → System → Netzwerk manuell eintragen: ${url}"
}

write_frpc_from_pair() {
  local proxy_name subdomain server_addr server_port auth_token public_url
  proxy_name="$(jq -r '.tunnel.proxy_name' "${PAIR_FILE}")"
  subdomain="$(jq -r '.tunnel.subdomain' "${PAIR_FILE}")"
  server_addr="$(jq -r '.tunnel.server_addr' "${PAIR_FILE}")"
  server_port="$(jq -r '.tunnel.server_port' "${PAIR_FILE}")"
  auth_token="$(jq -r '.tunnel.auth_token' "${PAIR_FILE}")"
  public_url="$(jq -r '.public_url' "${PAIR_FILE}")"

  write_frpc_toml "${proxy_name}" "${subdomain}" "${server_addr}" "${server_port}" "${auth_token}"
  echo "${public_url}"
}

heartbeat_loop() {
  local token public_url
  token="$(cat "${TOKEN_FILE}")"
  public_url="$(jq -r '.public_url // empty' "${PAIR_FILE}" 2>/dev/null || true)"

  while true; do
    local tmp http_code
    tmp="$(mktemp)"
    http_code="$(curl -sS -o "${tmp}" -w '%{http_code}' \
      -X POST "${API_BASE}/device/heartbeat" \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "$(jq -n \
            --arg addon "$ADDON_VERSION" \
            --arg ha "${HA_VERSION:-unknown}" \
            '{addon_version:$addon, ha_version:$ha}')" || true)"

    if [[ "${http_code}" == "200" ]]; then
      public_url="$(jq -r '.public_url // empty' "${tmp}")"
      write_status "online" "Tunnel verbunden" "${public_url}"
    elif [[ "${http_code}" == "401" ]]; then
      log_err "Device-Token ungültig – bitte neu pairen (reset_pairing)"
      write_status "needs_pairing" "Token ungültig"
      rm -f "${tmp}"
      touch "${DATA_DIR}/repair_required"
      return 1
    else
      log_err "Heartbeat HTTP ${http_code}"
      write_status "degraded" "Heartbeat fehlgeschlagen (HTTP ${http_code})" "${public_url}"
    fi
    rm -f "${tmp}"
    sleep "${HEARTBEAT_INTERVAL}"
  done
}

run_frpc_supervised() {
  while true; do
    if [[ -f "${DATA_DIR}/repair_required" ]]; then
      log_err "Re-Pair erforderlich – frpc gestoppt"
      return 1
    fi
    log "Starte frpc …"
    write_status "connecting" "frpc startet" "$(jq -r '.public_url // empty' "${PAIR_FILE}" 2>/dev/null || true)"
    if ! /usr/local/bin/frpc -c "${FRPC_TOML}"; then
      log_err "frpc beendet – Neustart in 5s"
      write_status "reconnecting" "frpc Neustart"
      sleep 5
    else
      log "frpc sauber beendet – Neustart in 5s"
      sleep 5
    fi
  done
}

main() {
  mkdir -p "${DATA_DIR}"
  read_options

  if [[ "${RESET_PAIRING}" == "true" ]]; then
    log "reset_pairing=true – lösche gespeicherte Credentials"
    rm -f "${TOKEN_FILE}" "${PAIR_FILE}" "${FRPC_TOML}" "${DATA_DIR}/repair_required"
  fi

  if [[ ! -f "${TOKEN_FILE}" || ! -f "${PAIR_FILE}" ]]; then
    do_pair "${PAIRING_CODE}"
  else
    log "Vorhandenes Pairing geladen"
    write_frpc_from_pair >/dev/null
  fi

  local public_url
  public_url="$(jq -r '.public_url' "${PAIR_FILE}")"
  set_ha_external_url "${public_url}"

  heartbeat_loop &
  HEARTBEAT_PID=$!

  set +e
  run_frpc_supervised
  FRPC_RC=$?
  set -e

  kill "${HEARTBEAT_PID}" 2>/dev/null || true
  wait "${HEARTBEAT_PID}" 2>/dev/null || true
  exit "${FRPC_RC}"
}

main "$@"
