#!/usr/bin/env bash
# Build Evolution X 10 for kyoto on crave.io.
# Run from your Evolution X crave workspace (see README.md), e.g.:
#   crave run --no-patch -- "bash <(curl -fsSL https://raw.githubusercontent.com/YashDayani/local_manifests_kyoto/vic/crave-build.sh)"
set -euo pipefail

GITHUB_USER=${GITHUB_USER:-YashDayani}
VARIANT=${VARIANT:-userdebug}

# Local manifest with the kyoto device, vendor and Moto Camera repositories
rm -rf .repo/local_manifests
git clone --depth 1 -b vic "https://github.com/${GITHUB_USER}/local_manifests_kyoto" .repo/local_manifests

# crave's resync helper: repo sync with the workspace cache
/opt/crave/resync.sh

# Large prebuilts are stored as <100 MB parts
bash vendor/motorola/kyoto/reassemble.sh
bash vendor/motorola/MotCamera4-kyoto/reassemble.sh

# kyoto source patches (SystemUI QS settings cache, ...)
bash device/motorola/kyoto/patches/apply.sh

# Experiment: Compose Quick Settings with resizable tiles (COMPOSE_QS=off to skip)
bash device/motorola/kyoto/experiments/compose-qs/apply.sh "${COMPOSE_QS:-on}"

source build/envsetup.sh
lunch "lineage_kyoto-bp1a-${VARIANT}"
m evolution
