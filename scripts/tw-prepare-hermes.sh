#!/bin/bash

set -e

# Use this to update hermes. Commit .hermesversion after running this.
# This is kinda nasty, but to avoid building hermes ourselves we get artifacts from RN circleci.
# Artifacts are copied to our s3 bucket since circleci only keeps them for 30 days.

# `prepare_hermes_workspace` -> `Download Hermes tarball`
HERMES_TAG="8ad46117c3517b842c4da411ff4b8612364f5354"
# `build_hermesc_linux` -> `Artifacts`
HERMESC_LINUX_URL="https://output.circle-artifacts.com/output/job/92e4ce0a-8644-4b92-a696-f03af44ae8a4/artifacts/0/tmp/hermes/linux64-bin/hermesc"
# `build_hermes_macos` -> `Artifacts`
HERMESC_MACOS_URL="https://output.circle-artifacts.com/output/job/76a723af-ebff-4c55-8790-14cfd07a0e07/artifacts/0/tmp/hermes/osx-bin/hermesc"
HERMES_RUNTIME_IOS_URL="https://output.circle-artifacts.com/output/job/76a723af-ebff-4c55-8790-14cfd07a0e07/artifacts/0/tmp/hermes/output/hermes-runtime-darwin-v1000.0.0.tar.gz"

BUCKET_NAME="tw-react-native"
THIS_DIR=$(cd -P "$(dirname "$(realpath "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)
SDKS_DIR="${THIS_DIR}/../sdks"

echo $HERMES_TAG > "$SDKS_DIR/.hermesversion"

TMP_DIR=$(mktemp -d)

HERMESC_LINUX_LOCAL="$TMP_DIR/linux64-bin/hermesc"
HERMESC_MACOS_LOCAL="$TMP_DIR/osx-bin/hermesc"
HERMES_RUNTIME_IOS_LOCAL="$TMP_DIR/hermes-runtime-darwin-v1000.0.0.tar.gz"

echo "Downloading to $TMP_DIR"

curl $HERMESC_LINUX_URL -L --create-dirs -o $HERMESC_LINUX_LOCAL
curl $HERMESC_MACOS_URL -L --create-dirs -o $HERMESC_MACOS_LOCAL
curl $HERMES_RUNTIME_IOS_URL -L --create-dirs -o $HERMES_RUNTIME_IOS_LOCAL

aws s3 sync $TMP_DIR "s3://$BUCKET_NAME/hermes-$HERMES_TAG"

