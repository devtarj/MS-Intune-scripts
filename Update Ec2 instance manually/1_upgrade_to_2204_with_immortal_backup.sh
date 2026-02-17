#!/bin/bash

# with rollback functionality

# for normal run: sudo ./filname.sh
# for rollback run: sudo ./filename.sh --rollback

set -euo pipefail

#############################################
# Ubuntu 20.04 -> 22.04 Upgrade Script
# With Rollback Support
#############################################

############################
# CONFIG
############################
BASE_BACKUP_DIR="/root/preupgrade-backups"
LOGFILE="/var/log/ubuntu-20.04-to-22.04-upgrade.log"

############################
# LOGGING
############################
exec > >(tee -a "$LOGFILE") 2>&1

############################
# ROOT CHECK
############################
if [[ "$EUID" -ne 0 ]]; then
  echo "ERROR: Run as root"
  exit 1
fi

############################
# ARGUMENT PARSER
############################
MODE="upgrade"

if [[ "${1:-}" == "--rollback" ]]; then
  MODE="rollback"
fi

############################
# ROLLBACK MODE
############################
rollback() {

  echo "========== ROLLBACK MODE =========="

  LAST_BACKUP="$(ls -1dt "$BASE_BACKUP_DIR"/* 2>/dev/null | head -n1)"

  if [[ -z "$LAST_BACKUP" ]]; then
    echo "No backup found. Cannot rollback."
    exit 1
  fi

  echo "Using backup: $LAST_BACKUP"

  cd "$LAST_BACKUP"

  ################ Restore cron ################

  if [[ -f cron.tar.gz ]]; then
    echo "Restoring cron..."
    tar -xzf cron.tar.gz -C / --keep-newer-files || true
    systemctl restart cron || true
  fi

  ################ Restore immortal ################

  if [[ -f immortal-meta/path.txt ]]; then

    ORIG_PATH="$(cat immortal-meta/path.txt)"

    echo "Restoring immortal to $ORIG_PATH"

    mkdir -p "$(dirname "$ORIG_PATH")"

    if [[ -f immortal-meta/immortal ]]; then
      install -m 0755 immortal-meta/immortal "$ORIG_PATH"
    fi
  fi

  ################ Restore env ################

  if [[ -f immortal-env.tar.gz ]]; then
    echo "Restoring immortal environment..."
    tar -xzf immortal-env.tar.gz -C / --keep-newer-files || true
  fi

  ################ Restore packages ################

  if [[ -f immortal-packages.txt ]]; then

    echo "Reinstalling packages..."

    xargs -a immortal-packages.txt -r apt install -y || true
    xargs -a immortal-packages.txt -r apt-mark hold || true
  fi

  ################ Fix permissions ################

  chown root:root /etc/crontab || true
  chmod 644 /etc/crontab || true

  ################ Verify ################

  command -v immortal >/dev/null \
    && echo "immortal restored" \
    || echo "WARNING: immortal missing"

  systemctl is-active cron >/dev/null \
    && echo "cron running" \
    || echo "WARNING: cron stopped"

  echo "========== ROLLBACK COMPLETE =========="

  exit 0
}

############################
# RUN ROLLBACK IF REQUESTED
############################
if [[ "$MODE" == "rollback" ]]; then
  rollback
fi

############################
# UPGRADE MODE
############################

echo "========== UPGRADE MODE =========="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

############################
# Keep configs
############################

cat <<EOF >/etc/apt/apt.conf.d/90-force-keep-configs
Dpkg::Options {
  "--force-confdef";
  "--force-confold";
}
EOF

############################
# Backup directory
############################

RUN_ID="$(date +%F_%H%M%S)"
BACKUP_DIR="$BASE_BACKUP_DIR/$RUN_ID"

mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

############################
# Save system state
############################

lsb_release -a > os-version.txt
dpkg --get-selections > dpkg-state.txt

############################
# Backup cron
############################

tar -czf cron.tar.gz \
  /etc/crontab \
  /etc/cron.* \
  /var/spool/cron/crontabs 2>/dev/null || true

############################
# Detect immortal
############################

IMMORTAL_BIN="$(command -v immortal || true)"

mkdir -p immortal-meta

if [[ -n "$IMMORTAL_BIN" ]]; then
  echo "$IMMORTAL_BIN" > immortal-meta/path.txt
  cp -a "$IMMORTAL_BIN" immortal-meta/
fi

############################
# Backup environment
############################

tar -czf immortal-env.tar.gz \
  "$IMMORTAL_BIN" \
  /etc/immortal \
  /var/lib/immortal \
  /usr/share/immortal 2>/dev/null || true

############################
# Packages
############################

dpkg -l | awk '/^ii/ {print $2}' | grep -E '^immortal($|-)'> immortal-packages.txt || true

if [[ -s immortal-packages.txt ]]; then
  xargs -a immortal-packages.txt apt-mark unhold || true
fi

############################
# Prevent autoremove
############################

cat <<EOF >/etc/apt/apt.conf.d/99-no-autoremove-safety
APT::Get::AutomaticRemove "false";
APT::Get::Remove "false";
EOF

############################
# Upgrade prep
############################

apt update -y --fix-missing --allow-releaseinfo-change
apt upgrade -y
apt install -y ubuntu-release-upgrader-core

############################
# Upgrade
############################

set +e
do-release-upgrade -f DistUpgradeViewNonInteractive
RC=$?
set -e

echo "Upgrade exit code: $RC"

############################
# Restore after upgrade
############################

if [[ -f cron.tar.gz ]]; then
  tar -xzf cron.tar.gz -C / --keep-newer-files || true
  systemctl restart cron || true
fi

############################
# Restore immortal
############################

if [[ -f immortal-meta/path.txt ]]; then

  ORIG_PATH="$(cat immortal-meta/path.txt)"

  if [[ ! -x "$ORIG_PATH" ]]; then
    mkdir -p "$(dirname "$ORIG_PATH")"
    install -m 0755 immortal-meta/immortal "$ORIG_PATH"
  fi
fi

if [[ -f immortal-env.tar.gz ]]; then
  tar -xzf immortal-env.tar.gz -C / --keep-newer-files || true
fi

############################
# Re-hold packages
############################

if [[ -s immortal-packages.txt ]]; then
  xargs -a immortal-packages.txt apt-mark hold || true
fi

############################
# Verify
############################

command -v immortal || echo "WARNING: immortal missing"
systemctl is-active cron || echo "WARNING: cron stopped"

############################
# Reboot
############################

if [[ -f /var/run/reboot-required ]]; then
  reboot
fi

echo "==========SCRIPT ENDED=========="