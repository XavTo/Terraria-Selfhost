#!/bin/sh
set -eu

# Racine persistante Railway
DATA_ROOT="${RAILWAY_VOLUME_MOUNT_PATH:-/data}"

# Chemins attendus par l'image ryshe/terraria
WORLD_DIR="/root/.local/share/Terraria/Worlds"
PLUGINS_DIR="/plugins"
LOG_DIR="/tshock/logs"

# Sous-dossiers persistants dans le volume unique
P_WORLD="${DATA_ROOT}/worlds"
P_PLUGINS="${DATA_ROOT}/plugins"
P_LOGS="${DATA_ROOT}/logs"

mkdir -p "$P_WORLD" "$P_PLUGINS" "$P_LOGS"

# Remplace un répertoire par un symlink (si nécessaire)
link_dir() {
  src="$1"
  dst="$2"

  # si c'est déjà un symlink, on ne touche pas
  if [ -L "$src" ]; then
    return 0
  fi

  # si le dossier existe (non vide), on le garde en sauvegarde (rare)
  if [ -d "$src" ] && [ "$(ls -A "$src" 2>/dev/null || true)" ]; then
    mv "$src" "${src}.bak.$(date +%s)" || true
  else
    rm -rf "$src" || true
  fi

  mkdir -p "$(dirname "$src")"
  ln -s "$dst" "$src"
}

# Pointage vers le volume unique
link_dir "$WORLD_DIR" "$P_WORLD"
link_dir "$PLUGINS_DIR" "$P_PLUGINS"
link_dir "$LOG_DIR" "$P_LOGS"

# Variables usuelles (l'image utilise CONFIGPATH/LOGPATH/WORLD_FILENAME) :contentReference[oaicite:4]{index=4}
: "${WORLD_FILENAME:=world.wld}"
: "${WORLD_SIZE:=2}"     # 1 small / 2 medium / 3 large
: "${MAXPLAYERS:=8}"
: "${PASSWORD:=}"
: "${MOTD:=}"
: "${GAME_PORT:=7777}"

export WORLD_FILENAME
export CONFIGPATH="$WORLD_DIR"
export LOGPATH="$LOG_DIR"

WORLD_PATH="${WORLD_DIR}/${WORLD_FILENAME}"

# Nettoyage des args pour éviter les doublons si quelqu’un a mis -world dans Railway
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

SAFE_ARGS="-maxplayers ${MAXPLAYERS} -port ${GAME_PORT}"

# Création auto si le monde n’existe pas
if [ ! -f "$WORLD_PATH" ]; then
  SAFE_ARGS="${SAFE_ARGS} -autocreate ${WORLD_SIZE}"
fi

if [ -n "$PASSWORD" ]; then
  SAFE_ARGS="${SAFE_ARGS} -password ${PASSWORD}"
fi

if [ -n "$MOTD" ]; then
  SAFE_ARGS="${SAFE_ARGS} -motd ${MOTD}"
fi

exec /bin/sh /tshock/bootstrap.sh $SAFE_ARGS $SANITIZED_ARGS
