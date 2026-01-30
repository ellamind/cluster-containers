#!/bin/bash
set -euo pipefail

# =============================================================================
# Container Build Script for Leonardo
# Usage: ./build_container.sh <container_name> [TAG=version]
# Example: TAG=v0.14.1 ./build_container.sh vllm
# =============================================================================

# -----------------------------------------------------------------------------
# Container Configurations
# Each container needs: DEFAULT_TAG, DOCKER_IMAGE, SIF_PREFIX
# -----------------------------------------------------------------------------

declare -A DEFAULT_TAGS=(
    [vllm]="v0.14.1"
    [sglang]="v0.5.7"
    [nemo]="25.11.nemotron_3_nano"
    [pytorch]="26.01-py3"
    [axolotl]="main-py3.12-cu129-2.9.1"
)

declare -A DOCKER_IMAGES=(
    [vllm]="vllm/vllm-openai"
    [sglang]="lmsysorg/sglang"
    [nemo]="nvcr.io/nvidia/nemo"
    [pytorch]="nvcr.io/nvidia/pytorch"
    [axolotl]="axolotlai/axolotl"
)

declare -A SIF_PREFIXES=(
    [vllm]="vllm-openai"
    [sglang]="sglang"
    [nemo]="nemo"
    [pytorch]="pytorch"
    [axolotl]="axolotl"
)

declare -A DISPLAY_NAMES=(
    [vllm]="vLLM"
    [sglang]="SGLang"
    [nemo]="NeMo"
    [pytorch]="PyTorch"
    [axolotl]="Axolotl"
)

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <container_name> [TAG=version]"
    echo ""
    echo "Available containers:"
    for name in "${!DEFAULT_TAGS[@]}"; do
        echo "  - $name (default: ${DEFAULT_TAGS[$name]})"
    done
    exit 1
fi

CONTAINER_NAME="$1"

if [[ ! -v "DEFAULT_TAGS[$CONTAINER_NAME]" ]]; then
    echo "Error: Unknown container '$CONTAINER_NAME'"
    echo ""
    echo "Available containers:"
    for name in "${!DEFAULT_TAGS[@]}"; do
        echo "  - $name"
    done
    exit 1
fi

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

TAG="${TAG:-${DEFAULT_TAGS[$CONTAINER_NAME]}}"
DOCKER_IMAGE="${DOCKER_IMAGES[$CONTAINER_NAME]}"
SIF_PREFIX="${SIF_PREFIXES[$CONTAINER_NAME]}"
DISPLAY_NAME="${DISPLAY_NAMES[$CONTAINER_NAME]}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/containers/${CONTAINER_NAME}"
LOG_DIR="${REPO_ROOT}/build_logs"
LOG_FILE="${LOG_DIR}/${CONTAINER_NAME}_build.log"
SIF_FILE="${OUTPUT_DIR}/${SIF_PREFIX}_${TAG}.sif"

# Cache stays on SCRATCH (persists between jobs)
export SINGULARITY_CACHEDIR="$SCRATCH/.singularity/cache"
mkdir -p "$SINGULARITY_CACHEDIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

# Log build info
{
    echo "=========================================="
    echo "${DISPLAY_NAME} Container Build"
    echo "=========================================="
    echo "Start time: $(date)"
    echo "Version: ${TAG}"
    echo "Docker image: ${DOCKER_IMAGE}:${TAG}"
    echo "Output: ${SIF_FILE}"
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
        singularity pull "'"${SIF_FILE}"'" "docker://'"${DOCKER_IMAGE}:${TAG}"'"
    ' 2>&1 | tee -a "${LOG_FILE}"

# Log completion
{
    echo ""
    echo "=========================================="
    echo "End time: $(date)"
    echo "=========================================="
} | tee -a "${LOG_FILE}"
