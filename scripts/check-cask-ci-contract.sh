#!/bin/sh

set -eu

workflow="${1:-.github/workflows/cask-ci.yml}"

if [ ! -f "$workflow" ]; then
  echo "missing cask CI workflow: $workflow" >&2
  exit 1
fi

require_literal() {
  value="$1"
  if ! grep -F "$value" "$workflow" >/dev/null; then
    echo "cask CI workflow is missing required value: $value" >&2
    exit 1
  fi
}

require_literal "permissions:"
require_literal "contents: read"
require_literal "macos-15"
require_literal "macos-15-intel"
require_literal "persist-credentials: false"
require_literal "Homebrew/actions/setup-homebrew@1f8e202ffddf94def7f42f6fa3a482e821489f9c"
require_literal 'brew-gh-api-token: ${{ github.token }}'
require_literal 'Casks/mitoriq-collector.rb must not be removed'
require_literal "brew trust --cask mitoriq/tap/mitoriq-collector"
require_literal "brew audit --strict --cask mitoriq-collector"
require_literal "brew style"
require_literal "brew install --cask mitoriq/tap/mitoriq-collector"
require_literal "mitoriq-collector version"
require_literal 'COLLECTOR_COSIGN_PUBLIC_KEY_SHA256: ${{ vars.COLLECTOR_COSIGN_PUBLIC_KEY_SHA256 }}'
require_literal 'release_key_sha256'
require_literal 'release_key_sha256" != "$COLLECTOR_COSIGN_PUBLIC_KEY_SHA256'
require_literal 'release_team_id'
require_literal "codesign --verify"
require_literal "spctl --assess"
require_literal 'signed_team_id'
require_literal 'source=Notarized Developer ID'
require_literal 'needs: cask'
require_literal 'CASK_RESULT: ${{ needs.cask.result }}'

if grep -Eq 'pull_request_target|secrets\.' "$workflow"; then
  echo "cask CI workflow must not execute untrusted pull requests with secrets" >&2
  exit 1
fi

if grep -E 'brew audit.*[[:space:]]--new([[:space:]]|$)' "$workflow" >/dev/null; then
  echo "custom tap CI must not apply official Homebrew notability checks" >&2
  exit 1
fi

if grep -Eq '^[[:space:]]+paths:' "$workflow"; then
  echo "cask CI workflow must run for every pull request when verify is required" >&2
  exit 1
fi

if ! awk '
  /brew tap --custom-remote mitoriq\/tap/ {
    tapped = 1
  }
  /brew trust --cask mitoriq\/tap\/mitoriq-collector/ {
    if (!tapped) {
      exit 1
    }
    trusted = 1
  }
  /brew audit/ {
    if (!trusted) {
      exit 1
    }
  }
  /brew install --cask mitoriq\/tap\/mitoriq-collector/ {
    if (!trusted) {
      exit 1
    }
  }
  END {
    if (!tapped || !trusted) {
      exit 1
    }
  }
' "$workflow"; then
  echo "cask CI workflow must trust the Collector cask after tapping and before audit and install" >&2
  exit 1
fi

if ! awk '
  /^[[:space:]]*uses:/ {
    if ($0 !~ /@[0-9a-f]{40}([[:space:]]|$)/) {
      exit 1
    }
  }
' "$workflow"; then
  echo "cask CI workflow actions must be pinned to full commit SHAs" >&2
  exit 1
fi
