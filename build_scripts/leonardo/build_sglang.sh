#!/bin/bash

# Configuration
TAG="${TAG:-v0.5.7}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/containers/sglang"
LOG_DIR="${REPO_ROOT}/build_logs"
LOG_FILE="${LOG_DIR}/sglang_build.log"

# Cache stays on SCRATCH (persists between jobs)
export SINGULARITY_CACHEDIR="$SCRATCH/.singularity/cache"
mkdir -p "$SINGULARITY_CACHEDIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# Log build info
{
    echo "=========================================="
    echo "SGLang Container Build"
    echo "=========================================="
    echo "Start time: $(date)"
    echo "Version: ${TAG}"
    echo "Output: ${OUTPUT_DIR}/sglang_${TAG}.sif"
    echo "Log file: ${LOG_FILE}"
    echo "Cache dir: ${SINGULARITY_CACHEDIR}"
    echo "=========================================="
    echo ""
} | tee "${LOG_FILE}"

# Request local tmpfs for the SIF creation step
srun -u -p lrd_all_serial --qos=normal -c 4 --time=2:00:00 --mem=29G --gres=tmpfs:200G \
    bash -c '
        # Use fast local tmpfs for temporary build files
        export SINGULARITY_TMPDIR=/tmp
        export TMPDIR=/tmp
        echo "SINGULARITY_TMPDIR: $SINGULARITY_TMPDIR"
        echo "TMPDIR: $TMPDIR"
        df -h /tmp
        singularity pull "'"${OUTPUT_DIR}"'/sglang_'"${TAG}"'.sif" "docker://lmsysorg/sglang:'"${TAG}"'"
    ' 2>&1 | tee -a "${LOG_FILE}"

# Log completion
{
    echo ""
    echo "=========================================="
    echo "End time: $(date)"
    echo "=========================================="
} | tee -a "${LOG_FILE}"