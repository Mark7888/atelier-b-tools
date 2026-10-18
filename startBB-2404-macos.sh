#!/bin/bash
# Start a bbatch console for the Atelier B workspace in the current directory.
# macOS version of startBB-2404.sh.
#
# Set ATELIERB_PATH to the Atelier B 24.04.2 installation (the folder or the
# .app bundle) if it is not found automatically, for example:
#   export ATELIERB_PATH="/Applications/AtelierB-free-24.04.2.app"

# Find the bbatch executable inside an installation folder or .app bundle.
find_bbatch() {
    local dir="$1" candidate
    [ -d "$dir" ] || return 1
    for candidate in "$dir/bin/bbatch" \
                     "$dir/Contents/Resources/bin/bbatch" \
                     "$dir/Contents/MacOS/bin/bbatch"; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    candidate=$(find "$dir" -maxdepth 5 -type f -name bbatch -perm -u+x 2>/dev/null | head -n 1)
    [ -n "$candidate" ] && echo "$candidate"
}

ABWS=$PWD
if [ ! -f "$ABWS/AtelierB" ]; then
    echo "Error: Configuration file 'AtelierB' not found in $ABWS" >&2
    exit 1
fi

BBATCH=""
if [ -n "$ATELIERB_PATH" ]; then
    BBATCH=$(find_bbatch "$ATELIERB_PATH")
else
    for dir in /Applications/*[Aa]telier* "$HOME"/Applications/*[Aa]telier* /opt/atelierb*; do
        BBATCH=$(find_bbatch "$dir") && [ -n "$BBATCH" ] && break
    done
fi
if [ -z "$BBATCH" ]; then
    echo "Error: bbatch not found. Set ATELIERB_PATH to the Atelier B installation directory." >&2
    exit 1
fi

# macOS uses DYLD_LIBRARY_PATH instead of LD_LIBRARY_PATH, and does not
# understand $ORIGIN, so the bin and bin/lib folders are given explicitly.
BIN_DIR=$(dirname "$BBATCH")
export DYLD_LIBRARY_PATH="$BIN_DIR:$BIN_DIR/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec "$BBATCH" -r="$ABWS/AtelierB" "$@"
