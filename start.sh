#!/bin/sh
set -eu

# Racine persistante (volume Railway monté sur /data)
DATA_ROOT="${RAILWAY_VOLUME_MOUNT_PATH:-/data}"

# Chemins de l'image ryshe/terraria
WORLD_DIR="/root/.local/share/Terraria/Worlds"
LOG_DIR="/tshock/logs"
SERVERPLUGINS_DIR="/tshock/ServerPlugins"
EXTERNAL_PLUGINS_DIR="/plugins"   # optionnel (dossier “drop”)

# Sous-dossiers persistants dans le volume unique
P_WORLD="${DATA_ROOT}/worlds"
P_LOGS="${DATA_ROOT}/logs"
P_SERVERPLUGINS="${DATA_ROOT}/serverplugins"
P_PLUGINS="${DATA_ROOT}/plugins"

mkdir -p "$P_WORLD" "$P_LOGS" "$P_SERVERPLUGINS" "$P_PLUGINS"

# Remplace un chemin par un symlink vers le volume (répertoire)
link_dir() {
  src="$1"
  dst="$2"

  if [ -L "$src" ]; then
    return 0
  fi

  if [ -d "$src" ] && [ "$(ls -A "$src" 2>/dev/null || true)" ]; then
    mv "$src" "${src}.bak.$(date +%s)" || true
  else
    rm -rf "$src" 2>/dev/null || true
  fi

  mkdir -p "$(dirname "$src")"
  ln -s "$dst" "$src"
}

link_dir "$WORLD_DIR" "$P_WORLD"
link_dir "$LOG_DIR" "$P_LOGS"
link_dir "$SERVERPLUGINS_DIR" "$P_SERVERPLUGINS"
link_dir "$EXTERNAL_PLUGINS_DIR" "$P_PLUGINS"

# Vars (avec défauts)
: "${WORLD_FILENAME:=arto.wld}"
: "${WORLD_SIZE:=2}"          # 1=Small 2=Medium 3=Large
: "${MAXPLAYERS:=8}"
: "${GAME_PORT:=7777}"
: "${PASSWORD:=}"
: "${MOTD:=}"

WORLD_PATH="${WORLD_DIR}/${WORLD_FILENAME}"

# (Optionnel) éviter l'erreur jq en créant un config.json vide côté Worlds
if [ ! -f "${WORLD_DIR}/config.json" ]; then
  printf '%s\n' '{}' > "${WORLD_DIR}/config.json"
fi

# Import optionnel: si vous déposez des DLL dans /plugins (persistant),
# on les copie vers ServerPlugins (persistant) au démarrage.
# (TShock charge les plugins depuis ServerPlugins)
if [ -d "$EXTERNAL_PLUGINS_DIR" ]; then
  find "$EXTERNAL_PLUGINS_DIR" -maxdepth 1 -type f -name '*.dll' -exec cp -f {} "$SERVERPLUGINS_DIR"/ \; 2>/dev/null || true
fi

# Nettoyage des args utilisateur pour éviter doublons dangereux
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

# Args serveur
ARGS="-configpath ${WORLD_DIR} -logpath ${LOG_DIR} -port ${GAME_PORT} -maxplayers ${MAXPLAYERS} -world ${WORLD_PATH}"

# Création auto du monde si absent (README de l'image : usage -autocreate) :contentReference[oaicite:2]{index=2}
if [ ! -f "$WORLD_PATH" ]; then
  ARGS="${ARGS} -autocreate ${WORLD_SIZE}"
fi

if [ -n "$PASSWORD" ]; then
  ARGS="${ARGS} -password ${PASSWORD}"
fi

if [ -n "$MOTD" ]; then
  ARGS="${ARGS} -motd ${MOTD}"
fi

# Lancement direct du serveur (commande mono utilisée couramment pour TShock) :contentReference[oaicite:3]{index=3}
cd /tshock
exec mono --server --gc=sgen -O=all TerrariaServer.exe $ARGS $SANITIZED_ARGS
