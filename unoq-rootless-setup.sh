#!/usr/bin/env bash
# UNO Q: independent rootless Docker + persistent hardware-device ownership.
# Run as the "arduino" user, not as root.
set -Eeuo pipefail

USER_NAME="$(id -un)"
USER_ID="$(id -u)"
HOME_DIR="$HOME"
ROOTLESS_SOCK="/run/user/${USER_ID}/docker.sock"
ROOTLESS_SCRIPT_DIR="/usr/share/docker.io/contrib"
HELPER_DIR="${HOME_DIR}/.local/bin/unoq-rootless"
RULE_FILE="/etc/udev/rules.d/99-unoq-hardware.rules"

if [[ "$USER_NAME" != "arduino" || "$USER_ID" -eq 0 ]]; then
  echo "ERROR: Run as the arduino account (without sudo)." >&2
  exit 1
fi
if [[ "$(findmnt -no FSTYPE -T "$HOME_DIR")" != "ext4" ]]; then
  echo "WARNING: Home is not on ext4; check Docker overlay2 compatibility." >&2
fi
if [[ "$(findmnt -no SOURCE -T "$HOME_DIR")" == "$(findmnt -no SOURCE -T /)" ]]; then
  echo "ERROR: Home and / share the same filesystem. Stopping to avoid consuming root partition." >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y --no-install-recommends rootlesskit uidmap slirp4netns acl

if [[ ! -x "${ROOTLESS_SCRIPT_DIR}/dockerd-rootless.sh" || ! -x "${ROOTLESS_SCRIPT_DIR}/dockerd-rootless-setuptool.sh" ]]; then
  echo "ERROR: Debian docker.io Rootless scripts not present in ${ROOTLESS_SCRIPT_DIR}." >&2
  exit 1
fi
if ! grep -q "^${USER_NAME}:[0-9]*:65536" /etc/subuid || ! grep -q "^${USER_NAME}:[0-9]*:65536" /etc/subgid; then
  echo "ERROR: Expected subordinate UID/GID range for ${USER_NAME}; check /etc/subuid and /etc/subgid." >&2
  exit 1
fi

# Debian's setup tool looks for `docker` beside the setup script; use a persistent
# helper directory, not a temporary PATH that would break the systemd service.
mkdir -p "$HELPER_DIR"
ln -sfn "${ROOTLESS_SCRIPT_DIR}/dockerd-rootless.sh" "$HELPER_DIR/dockerd-rootless.sh"
ln -sfn "${ROOTLESS_SCRIPT_DIR}/dockerd-rootless-setuptool.sh" "$HELPER_DIR/dockerd-rootless-setuptool.sh"
ln -sfn "$(command -v docker)" "$HELPER_DIR/docker"

if [[ ! -f "${HOME_DIR}/.config/systemd/user/docker.service" ]]; then
  PATH="$HELPER_DIR:$PATH" "$HELPER_DIR/dockerd-rootless-setuptool.sh" install --force
fi

# Keep the factory Docker context untouched; explicitly select rootless.
if ! docker context inspect rootless >/dev/null 2>&1; then
  docker context create rootless --docker "host=unix://${ROOTLESS_SOCK}"
fi

systemctl --user daemon-reload
systemctl --user enable --now docker.service
sudo loginctl enable-linger "$USER_NAME"

# Broad by hardware class, not by camera model. This expands arduino's access
# to sensitive hardware, including DSP; use only on a dedicated device.
sudo tee "$RULE_FILE" >/dev/null <<'RULES'
# UNO Q product-development hardware access for rootless Docker (arduino UID)
ACTION=="add|change", SUBSYSTEM=="video4linux", OWNER="arduino", MODE="0660"
ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]*", OWNER="arduino", MODE="0660"
ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="renderD*", OWNER="arduino", MODE="0660"
ACTION=="add|change", SUBSYSTEM=="dma_heap", OWNER="arduino", MODE="0660"
ACTION=="add|change", SUBSYSTEM=="gpio", KERNEL=="gpiochip*", OWNER="arduino", MODE="0660"
ACTION=="add|change", SUBSYSTEM=="misc", KERNEL=="fastrpc-*", OWNER="arduino", MODE="0660"
RULES
sudo udevadm control --reload-rules
# Avoid triggering FastRPC or other DSP devices while they may be in use.
for subsystem in video4linux drm dma_heap gpio; do
  sudo udevadm trigger --action=change --subsystem-match="$subsystem"
done
sudo udevadm settle

echo
printf 'Official Docker: '
docker --context default info --format '{{.DockerRootDir}}'
printf 'Rootless Docker: '
docker --context rootless info --format '{{.DockerRootDir}}'
printf 'Rootless service: '
systemctl --user is-enabled docker.service
loginctl show-user "$USER_NAME" -p Linger
printf 'Rules file: %s\n' "$RULE_FILE"
echo 'NOTE: FastRPC ownership applies on its next add/change event or reboot.'
echo 'NOTE: Device access and AI acceleration still require separate functional tests.'
