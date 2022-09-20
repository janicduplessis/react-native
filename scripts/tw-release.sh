#!/bin/bash

set -e

# This is kinda nasty, but to avoid building hermes ourselves we get artifacts from RN circleci.

THIS_DIR=$(cd -P "$(dirname "$(realpath "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)
HERMES_VERSION=$(<"${THIS_DIR}/../sdks/.hermesversion")
BUCKET_URL="https://tw-react-native.s3.us-west-2.amazonaws.com/hermes-$HERMES_VERSION"
HERMESC_DIR="${THIS_DIR}/../sdks/hermesc"

curl "$BUCKET_URL/linux64-bin/hermesc" -L --create-dirs -o "$HERMESC_DIR/linux64-bin/hermesc"
curl "$BUCKET_URL/osx-bin/hermesc" -L --create-dirs -o "$HERMESC_DIR/osx-bin/hermesc"

chmod +x "$HERMESC_DIR/linux64-bin/hermesc" "$HERMESC_DIR/osx-bin/hermesc"

node ./scripts/publish-npm.js --dry-run
npm publish
