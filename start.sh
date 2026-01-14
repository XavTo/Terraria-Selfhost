#!/bin/sh
set -eu

# Volume unique Railway
DATA_ROOT="${RAILWAY_VOLUME_MOUNT_PATH:-/data}"

# Chemins attendus par l'image ryshe/terraria (voir README / Dockerfile)
WORLD_DIR="/root/.local/share/Terraria/Worlds"
LOG_DIR="/tshock/logs"
PLUGINS_DIR="/plugins"

# Cibles persistantes dans le volume unique
P_WORLD="${DATA_ROOT}/world"
P_LOGS="${DATA_ROOT}/logs"
P_PLUGINS="${DATA_ROOT}/plugins"

mkdir -p "$P_WORLD" "$P_LOGS" "$P_PLUGINS"

# Remplace un dossier par un symlink vers le volume
link_dir() {
  src="$1"
  dst="$2"

  if [ -L "$src" ]; then
    return 0
  fi

  rm -rf "$src" 2>/dev/null || true
  mkdir -p "$(dirname "$src")"
  ln -s "$dst" "$src"
}

link_dir "$WORLD_DIR" "$P_WORLD"
link_dir "$LOG_DIR" "$P_LOGS"
link_dir "$PLUGINS_DIR" "$P_PLUGINS"

# Evite l'erreur jq du bootstrap quand config.json n'existe pas
# (le README indique que "Any config.json in the directory will automatically be loaded") :contentReference[oaicite:2]{index=2}
if [ ! -f "${WORLD_DIR}/config.json" ]; then
  printf '%s\n' '{}' > "${WORLD_DIR}/config.json"
fi

# Evite le bug "[: =: unexpected operator" si WORLD_FILENAME est vide
# (l'image utilise WORLD_FILENAME pour démarrer un monde existant) :contentReference[oaicite:3]{index=3}
if [ -z "${WORLD_FILENAME:-}" ]; then
  # si un .wld existe déjà, on prend le premier
  first_wld="$(ls -1 "${WORLD_DIR}"/*.wld 2>/dev/null | head -n 1 || true)"
  if [ -n "$first_wld" ]; then
    WORLD_FILENAME="$(basename "$first_wld")"
    export WORLD_FILENAME
  else
    WORLD_FILENAME="world.wld"
    export WORLD_FILENAME
  fi
fi

# Si le monde n'existe pas encore, on demande une autocreation
: "${WORLD_SIZE:=2}"  # 1=Small, 2=Medium, 3=Large (convention de l'image / Terraria) :contentReference[oaicite:4]{index=4}
if [ ! -f "${WORLD_DIR}/${WORLD_FILENAME}" ]; then
  set -- "$@" -autocreate "${WORLD_SIZE}"
fi

# Sécurité : si quelqu'un a mis -world/-configpath/-logpath dans Railway, on les supprime (doublons => crash)
SANITIZED_ARGS=""
skip_next=0
for a in "$@"; do
  if [ "$skip_next" -eq 1 ]; then
    skip_next=0
    continue
  fi
  case "$a" in
    -world|-configpath|-logpath)
      skip_next=1
      continue
      ;;
    *)
      SANITIZED_ARGS="${SANITIZED_ARGS} $(printf "%s" "$a")"
      ;;
  esac
done

# Lancer exactement comme l'image le prévoit: WORKDIR /tshock + bootstrap.sh :contentReference[oaicite:5]{index=5}
cd /tshock
# shellcheck disable=SC2086
exec /bin/sh bootstrap.sh $SANITIZED_ARGS
