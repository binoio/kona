#!/bin/zsh
#
# release-mas.sh: Build, sign, package, and upload the Mac App Store build of
# Kona. Runs alongside Scripts/release.sh (Developer ID + Sparkle) — same
# VERSION, second distribution channel. This script does not tag; the
# Developer ID release owns the git tag for a version.
#
# One-time setup (beyond release.sh's prerequisites):
#   1. Certificates in the login Keychain: "Apple Distribution" (or the older
#      "3rd Party Mac Developer Application") and "3rd Party Mac Developer
#      Installer" (aka Mac Installer Distribution).
#   2. A Mac App Store provisioning profile for io.binoio.Kona saved as
#      Scripts/KonaAppStore.provisionprofile (or set KONA_MAS_PROFILE).
#   3. An App Store Connect API key with the App Manager role (the notary
#      key's Developer role cannot upload builds): put AuthKey_<ID>.p8 in
#      ~/.appstoreconnect/private_keys/ and export KONA_ASC_KEY_ID and
#      KONA_ASC_ISSUER_ID. Without them the script stops after producing the
#      .pkg, which can be uploaded manually with the Transporter app.
#   4. An app record for io.binoio.Kona in App Store Connect.

set -euo pipefail

# Feature flag: App Store releases are disabled while Kona ships outside the
# MAS only. The shell is still developed dual-track (KONA_MAS=1 swift build);
# flip this gate deliberately when the channel goes live.
if [[ "${KONA_MAS:-0}" != "1" ]]; then
    echo "error: Mac App Store releases are currently disabled (feature flag)." >&2
    echo "       Kona releases outside the App Store only; run with KONA_MAS=1" >&2
    echo "       to override once the channel's prerequisites are provisioned." >&2
    exit 1
fi
export KONA_MAS=1

TEAM_ID="43L352U8Y8"
PROFILE="${KONA_MAS_PROFILE:-Scripts/KonaAppStore.provisionprofile}"
ENTITLEMENTS="Scripts/KonaAppStore.entitlements"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

VERSION=$(tr -d '[:space:]' < VERSION)
APP="build/mas/Kona.app"
PKG="build/mas/Kona-${VERSION}.pkg"

echo "==> Preflight for Kona ${VERSION} (Mac App Store)"
[[ -z "$(git status --porcelain)" ]] || { echo "error: working tree not clean" >&2; exit 1; }
[[ -f "$ENTITLEMENTS" ]] || { echo "error: $ENTITLEMENTS missing" >&2; exit 1; }
[[ -f "$PROFILE" ]] || {
    echo "error: provisioning profile not found at $PROFILE" >&2
    echo "       Create a Mac App Store profile for io.binoio.Kona in the" >&2
    echo "       developer portal, or point KONA_MAS_PROFILE at it." >&2
    exit 1
}

# App signing identity: prefer the modern name, fall back to the older one
APP_IDENTITY="${KONA_MAS_APP_IDENTITY:-}"
if [[ -z "$APP_IDENTITY" ]]; then
    for name in "Apple Distribution" "3rd Party Mac Developer Application"; do
        if security find-identity -v -p macappstore 2>/dev/null | grep -q "$name.*$TEAM_ID"; then
            APP_IDENTITY="$(security find-identity -v -p macappstore | grep -o "\"$name[^\"]*\"" | head -1 | tr -d '"')"
            break
        fi
    done
fi
[[ -n "$APP_IDENTITY" ]] || { echo "error: no Apple Distribution identity for team $TEAM_ID in keychain" >&2; exit 1; }

PKG_IDENTITY="${KONA_MAS_PKG_IDENTITY:-}"
if [[ -z "$PKG_IDENTITY" ]]; then
    PKG_IDENTITY="$(security find-identity -v 2>/dev/null | grep -o '"3rd Party Mac Developer Installer[^"]*"' | head -1 | tr -d '"')"
fi
[[ -n "$PKG_IDENTITY" ]] || { echo "error: no Mac Installer Distribution identity in keychain" >&2; exit 1; }

echo "    app: $APP_IDENTITY"
echo "    pkg: $PKG_IDENTITY"

echo "==> Building"
swift build -c release
APP_VERSION="$VERSION" bash Scripts/bundle-mas.sh

echo "==> Embedding provisioning profile"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"

echo "==> Codesigning (sandbox entitlements; no hardened runtime for MAS)"
codesign -f -s "$APP_IDENTITY" --entitlements "$ENTITLEMENTS" "$APP"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements - "$APP" | grep -q "com.apple.security.app-sandbox" || {
    echo "error: signed app is missing the sandbox entitlement" >&2; exit 1
}

echo "==> Building installer package"
rm -f "$PKG"
productbuild --component "$APP" /Applications --sign "$PKG_IDENTITY" "$PKG"

if [[ -z "${KONA_ASC_KEY_ID:-}" || -z "${KONA_ASC_ISSUER_ID:-}" ]]; then
    echo "==> Done (not uploaded): $PKG"
    echo "    Set KONA_ASC_KEY_ID and KONA_ASC_ISSUER_ID (App Manager API key)"
    echo "    to upload from here, or submit the pkg with the Transporter app."
    exit 0
fi

echo "==> Uploading to App Store Connect"
xcrun altool --upload-app -f "$PKG" -t macos \
    --apiKey "$KONA_ASC_KEY_ID" --apiIssuer "$KONA_ASC_ISSUER_ID"

echo "==> Done: Kona ${VERSION} uploaded. Finish the release in App Store Connect"
echo "    (select the build, release notes, and submit for review)."
