#!/bin/bash
# Turn the current empty directory into an Atelier B workspace.
# macOS version of initABWS-2404.sh.

# Find the installation root (the folder that holds bin/bbatch and share/)
# inside an installation folder or .app bundle.
find_atb_home() {
    local dir="$1" candidate
    [ -d "$dir" ] || return 1
    for candidate in "$dir" "$dir/Contents/Resources" "$dir/Contents/MacOS"; do
        if [ -x "$candidate/bin/bbatch" ]; then
            (cd "$candidate" && pwd -P)
            return 0
        fi
    done
    candidate=$(find "$dir" -maxdepth 5 -type f -name bbatch -perm -u+x 2>/dev/null | head -n 1)
    [ -n "$candidate" ] || return 1
    (cd "$(dirname "$candidate")/.." && pwd -P)
}

# 1. Check that the current directory is empty (macOS Finder may have
#    added a .DS_Store file; that one is ignored).
if [ -n "$(ls -A | grep -v '^\.DS_Store$')" ]; then
    echo "Error: Directory is not empty! Execution aborted."
    exit 1
fi

# 2. Suggest an installation found in the usual places.
DEFAULT_PATH=""
for dir in /Applications/*[Aa]telier* "$HOME"/Applications/*[Aa]telier* /opt/atelierb*; do
    if [ -d "$dir" ] && find_atb_home "$dir" >/dev/null; then
        DEFAULT_PATH="$dir"
        break
    fi
done

if [ -n "$DEFAULT_PATH" ]; then
    echo "Please enter the installation path for Atelier B 24.04.2"
    echo "(press Enter to use: $DEFAULT_PATH):"
else
    echo "Please enter the installation path for Atelier B 24.04.2:"
fi
read -r ATELIERB_PATH
ATELIERB_PATH="${ATELIERB_PATH:-$DEFAULT_PATH}"

# 3. Validate the path.
if [ -z "$ATELIERB_PATH" ]; then
    echo "Error: The path cannot be empty!"
    exit 1
fi
if [ ! -d "$ATELIERB_PATH" ]; then
    echo "Error: The directory '$ATELIERB_PATH' does not exist."
    exit 1
fi
ATB_HOME=$(find_atb_home "$ATELIERB_PATH")
if [ -z "$ATB_HOME" ]; then
    echo "Error: bbatch was not found in '$ATELIERB_PATH'."
    exit 1
fi
if [ ! -d "$ATB_HOME/share" ]; then
    echo "Warning: '$ATB_HOME/share' not found; check the BART and b2rust paths in AtelierB."
fi

# 4. Create the 'bdb' and 'Archives' directories.
mkdir -p "bdb" "Archives" || exit 1

# 5. Absolute path of 'bdb' (realpath is missing on older macOS).
BDB_ABS_PATH=$(cd "bdb" && pwd -P)

# 6. Create the 'AtelierB' configuration file.
cat <<CONF > AtelierB
!===========================================================================
! AtelierB Global resources
!===========================================================================
!
! Tools resources
!
ATB*ATB*Logic_Solver_Command:krt -a c70000d3000e100g10000h10000m10000000n130000o110400s60000t1100x5000y5500
ATB*ATB*TypeChecker_Command:TC.kin
ATB*ATB*Xref_Command:xref
ATB*ATB*Proof_Obligations_Generator_Command:PO.kin
ATB*ATB*Proof_Obligations_Generator_NG_Command:pog
ATB*ATB*Proof_Obligations_Generator_EvB_Command:pogevb
ATB*ATB*Proof_Obligations_Generator_NG:TRUE
ATB*ATB*Binst_Command:binst
ATB*ATB*Prover_Command:MU.kin
ATB*ATB*KParser_Command:pk -a m20000
ATB*ATB*Predicate_Prover_Command:PP.kin
ATB*ATB*BED_Command:bed
ATB*ATB*Read_PMI_Command:READPMI.kin
ATB*ATB*ML_Command:ML.kin
ATB*ATB*ComenC_Translator_Command:b2c
ATB*ATB*Delta_Component_Command:DELTA3.kin
ATB*ATB*Bart_Refiner_Command:bart
ATB*ATB*BBeautifuler_Command:BBeautifuler
ATB*ATB*Print_Command:bprint
ATB*ATB*Bxml_Command:bxml
ATB*ATB*B_Compiler_Command:bcomp
ATB*ATB*External_Proof_Command:extprove
ATB*ATB*Replay_External_Proof_Command:extreplay
ATB*ATB*Proof_Metrics:extmetrics
ATB*ATB*Rust_Translator_Command:b2rust

!===========================================================================
! TypeChecker Resource : Enable Local Operations
!===========================================================================
ATB*TC*Enable_Local_Operations:TRUE

! Set to true not to use prover extensions defined in the 3.7 version
ATB*PR*Pr_3_6_compatibility:FALSE

!===========================================================================
! Resources to use third-party provers
!===========================================================================
ATB*Proof*Why3Writer:po2why
ATB*Proof*Pog_Smt_Simplified_Encode:pog2smt
ATB*Proof*Pog_Smt_PP_Encode:ppTransSmt
ATB*Proof*Smt_Simplified_Read_Status:simple_smt_solver_reader
ATB*Proof*Smt_Read_Status:smt_solver_reader
ATB*Proof*Pog_TPTP_PP_Encode:ppTransTPTP
ATB*Proof*TPTP_Read_Status:tptp_reader
ATB*Proof*Pog_Why_Encode:pog2why
ATB*Proof*AltErgo_Read_Status:altergo_reader
!===========================================================================
! Installation path dependent resources
!===========================================================================
ATB*BART*RefinerFile:${ATB_HOME}/share/bart/PatchRaffiner.rmf
ATB*B2RUST*Configuration_Directory:${ATB_HOME}/share/b2rust/config/
ATB*ATB*Atelier_Database_Directory:${BDB_ABS_PATH}
CONF

echo "Success: 'bdb' and 'Archives' directories, and 'AtelierB' config file have been created."
echo "Tip: export ATELIERB_PATH=\"$ATELIERB_PATH\" so startBB-2404-macos.sh finds this installation."
