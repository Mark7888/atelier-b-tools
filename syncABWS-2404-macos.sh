#!/bin/bash
# Synchronize the workspace directory with the Atelier B workspace database.
# macOS version of syncABWS-2404.sh (works with the stock bash 3.2 and BSD tools).

PROJECT_ROOT=$(pwd)

# 1. Check that the Atelier B configuration file exists here.
if [ ! -f "AtelierB" ]; then
    echo "Error: 'AtelierB' config file not found in $PROJECT_ROOT."
    exit 1
fi

# 2. Find startBB-2404-macos.sh beside this script, or else on PATH.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd -P)
if [ -x "$SCRIPT_DIR/startBB-2404-macos.sh" ]; then
    AT_BIN="$SCRIPT_DIR/startBB-2404-macos.sh"
elif command -v startBB-2404-macos.sh >/dev/null 2>&1; then
    AT_BIN=$(command -v startBB-2404-macos.sh)
else
    echo "Error: startBB-2404-macos.sh was not found beside this script or on PATH."
    exit 1
fi

# Run commands in bbatch via stdin.
run_bbatch() {
    "$AT_BIN" <<CMDS
$1
quit
CMDS
}

# Exact, whole-line match of $1 in the newline separated list $2.
in_list() {
    printf '%s\n' "$2" | grep -qxF -- "$1"
}

# Registered project names start with two spaces in the spl output.
list_projects() {
    run_bbatch "spl" | tr -d '\r' | grep '^  ' | awk '{print $1}'
}

echo "Starting Atelier B workspace synchronization..."

# 3. Projects currently registered in the database.
CURRENT_PROJECTS=$(list_projects)

# 4. Project directories on disk (skip bdb, Archives and hidden folders).
ACTUAL_DIRS=$(find . -mindepth 1 -maxdepth 1 -type d ! -name "bdb" ! -name "Archives" ! -name ".*" | sed 's|^\./||' | sort -u)

# --- PART A: PROJECT MANAGEMENT (Add and Remove) ---

for dir in $ACTUAL_DIRS; do
    PDB_DIR="$PROJECT_ROOT/$dir/bdp"
    LANG_DIR="$PROJECT_ROOT/$dir/lang"
    TEMP_LANG="$PROJECT_ROOT/$dir/lang-tmp"

    if in_list "$dir" "$CURRENT_PROJECTS"; then
        echo ">> Project '$dir' is already registered."
        continue
    fi

    echo ">> New project detected: '$dir'. Preparing registration..."

    # If a lang directory exists (e.g. from a Git clone), move it aside.
    if [ -d "$LANG_DIR" ]; then
        if [ -e "$TEMP_LANG" ]; then
            echo "   Error: '$TEMP_LANG' already exists; cannot move lang safely. Skipping."
            continue
        fi
        echo "   [!] Moving existing lang to lang-tmp..."
        mv "$LANG_DIR" "$TEMP_LANG"
    fi

    # bbatch needs the directories to exist and be empty at creation.
    echo "   [!] Creating empty bdp and lang directories..."
    mkdir -p "$PDB_DIR" "$LANG_DIR"

    echo "   Registering project in Atelier B..."
    run_bbatch "create_project $dir $PDB_DIR $LANG_DIR"

    # Restore the original files (C implementations, etc.) without
    # overwriting anything bbatch created.
    if [ -d "$TEMP_LANG" ]; then
        echo "   [!] Restoring files from lang-tmp back to lang..."
        cp -Rn "$TEMP_LANG"/. "$LANG_DIR/" 2>/dev/null
        rm -rf "$TEMP_LANG"
    fi
    echo "   Project '$dir' successfully integrated."
done

# Remove orphaned projects (registered in the database but missing on disk).
for proj in $CURRENT_PROJECTS; do
    if [ ! -d "$PROJECT_ROOT/$proj" ]; then
        echo ">> Project folder '$proj' not found. Removing from database (rp)..."
        run_bbatch "rp $proj"
    fi
done

# --- REFRESH LIST ---
echo "Refreshing project list for file synchronization..."
CURRENT_PROJECTS=$(list_projects)

# --- PART B: FILE SYNCHRONIZATION (sml/af/rc) ---

for proj in $ACTUAL_DIRS; do
    if ! in_list "$proj" "$CURRENT_PROJECTS"; then
        echo "Problem with the $proj!"
        continue
    fi

    echo "Syncing components for: $proj"

    # Indented sml lines hold the registered component names.
    # (macOS grep has no -P, so a POSIX class is used instead.)
    REG_COMPONENTS=$(run_bbatch "op $proj
sml" | tr -d '\r' | grep -E '^[[:blank:]]+' | awk '{print $1}')

    SRC_DIR="$PROJECT_ROOT/$proj/src"
    if [ ! -d "$SRC_DIR" ]; then
        echo "   Warning: src directory not found. Skipping files."
        continue
    fi

    DISK_FILES=$(find "$SRC_DIR" -maxdepth 1 -type f \( -name "*.mch" -o -name "*.ref" -o -name "*.imp" \) -exec basename {} \;)

    CMD_BATCH="op $proj"
    HAS_CHANGES=false

    # Add source files that are not registered yet (af).
    for f in $DISK_FILES; do
        comp_name="${f%.*}"
        if ! in_list "$comp_name" "$REG_COMPONENTS"; then
            echo "   [+] Adding new component: $f"
            CMD_BATCH="$CMD_BATCH
af $SRC_DIR/$f"
            HAS_CHANGES=true
        fi
    done

    # Remove components whose files are gone (rc).
    for comp in $REG_COMPONENTS; do
        if [ -n "$comp" ] && [ ! -f "$SRC_DIR/$comp.mch" ] && [ ! -f "$SRC_DIR/$comp.ref" ] && [ ! -f "$SRC_DIR/$comp.imp" ]; then
            echo "   [-] Removing missing component: $comp"
            CMD_BATCH="$CMD_BATCH
rc $comp"
            HAS_CHANGES=true
        fi
    done

    if [ "$HAS_CHANGES" = true ]; then
        run_bbatch "$CMD_BATCH"
    else
        echo "   Components are up to date."
    fi
done

echo "-----------------------------------------------"
echo "Synchronization complete."
