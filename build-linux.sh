#!/usr/bin/env bash
# Build Evolution X 10 (Android 15) for kyoto on a plain Ubuntu 22.04/24.04 x86-64 machine.
# Needs ~32 GB RAM (64 GB better), ~400 GB free disk, a fast connection.
#
# Usage (as a normal user with sudo):
#   curl -fsSL https://raw.githubusercontent.com/YashDayani/local_manifests_kyoto/vic/build-linux.sh | bash
# Re-running skips steps that are already done; set VARIANT=user for a user build.
# COMPOSE_QS=off builds without the Compose Quick Settings experiment.
set -euo pipefail

if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
  echo "This must run on an x86-64 Linux machine (Ubuntu 22.04/24.04), not $(uname -s) $(uname -m)."
  echo "Android 15 cannot be built on macOS. Run this command on your Linux PC instead."
  exit 1
fi

GITHUB_USER=${GITHUB_USER:-YashDayani}
VARIANT=${VARIANT:-userdebug}
SRC=${SRC:-$HOME/evox}
JOBS=${JOBS:-$(nproc --all)}

echo "== Build host: $(nproc --all) cores, $(free -g | awk '/Mem:/{print $2}') GB RAM, $(df -h --output=avail "$HOME" | tail -1) free"

# 1. Packages (AOSP/LineageOS build requirements)
if ! command -v repo >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
    git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool \
    libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools \
    xsltproc zip zlib1g-dev python3 python-is-python3 openjdk-17-jdk
  mkdir -p "$HOME/bin"
  curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
  chmod +x "$HOME/bin/repo"
fi
export PATH="$HOME/bin:$PATH"
git config --global user.name >/dev/null || git config --global user.name "kyoto builder"
git config --global user.email >/dev/null || git config --global user.email "builder@localhost"
git lfs install --skip-repo

# ccache keeps rebuilds fast
export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache
ccache -M 50G >/dev/null

# 2. Evolution X source + kyoto local manifest
mkdir -p "$SRC" && cd "$SRC"
if [[ ! -d .repo ]]; then
  repo init -u https://github.com/Evolution-X/manifest -b vic --git-lfs --depth=1
fi
rm -rf .repo/local_manifests
git clone --depth 1 -b vic "https://github.com/${GITHUB_USER}/local_manifests_kyoto" .repo/local_manifests

# 3. Sync (first time downloads ~100+ GB)
repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags

# 4. Large prebuilts are stored as <100 MB parts
bash vendor/motorola/kyoto/reassemble.sh
bash vendor/motorola/MotCamera4-kyoto/reassemble.sh

# 5. Build
# kyoto source patches (SystemUI QS settings cache, ...)
bash device/motorola/kyoto/patches/apply.sh

# Experiment: Compose Quick Settings with resizable tiles (COMPOSE_QS=off to skip)
bash device/motorola/kyoto/experiments/compose-qs/apply.sh "${COMPOSE_QS:-on}"

source build/envsetup.sh
lunch "lineage_kyoto-bp1a-${VARIANT}"
m evolution 2>&1 | tee "$SRC/build-kyoto.log"

echo "== Output:"
ls -lh out/target/product/kyoto/*.zip out/target/product/kyoto/boot.img 2>/dev/null || true
