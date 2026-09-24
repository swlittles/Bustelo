#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${RELEASE_TAG:?Set the tested version tag}"
[[ "$RELEASE_TAG" = "v$(cat VERSION)" ]] || { echo 'Tag/version mismatch.' >&2; exit 1; }
git rev-parse --verify "refs/tags/$RELEASE_TAG" >/dev/null
bash scripts/release-notes.sh > release-assets/NOTES.md
# A pre-created draft can be completed; published releases are immutable here.
if draft=$(gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft 2>/dev/null); then
    [[ "$draft" = true ]] || { echo 'Release is already published; refusing to replace its assets.' >&2; exit 1; }
    gh release upload "$RELEASE_TAG" release-assets/Bustelo-* release-assets/appcast.xml --clobber
    gh release edit "$RELEASE_TAG" --title "Bustelo $RELEASE_TAG" --notes-file release-assets/NOTES.md --draft=false --latest
else
    gh release create "$RELEASE_TAG" release-assets/Bustelo-* release-assets/appcast.xml --verify-tag --title "Bustelo $RELEASE_TAG" --notes-file release-assets/NOTES.md --latest
fi
