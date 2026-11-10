# Container catalog, shared by the build scripts (source it, then call
# container_config NAME). A new container needs one line in each table.

declare -A DEFAULT_TAGS=(
    [vllm]="v0.21.0-cu129"
    [sglang]="v0.5.12-cu129"
    [nemo]="26.04"
    [nemo-curator]="26.02"
    [pytorch]="26.01-py3"
    [axolotl]="main-py3.12-cu129-2.9.1"
)

declare -A DOCKER_IMAGES=(
    [vllm]="vllm/vllm-openai"
    [sglang]="lmsysorg/sglang"
    [nemo]="nvcr.io/nvidia/nemo"
    [nemo-curator]="nvcr.io/nvidia/nemo-curator"
    [pytorch]="nvcr.io/nvidia/pytorch"
    [axolotl]="axolotlai/axolotl"
)

declare -A SIF_PREFIXES=(
    [vllm]="vllm-openai"
    [sglang]="sglang"
    [nemo]="nemo"
    [nemo-curator]="nemo-curator"
    [pytorch]="pytorch"
    [axolotl]="axolotl"
)

declare -A DISPLAY_NAMES=(
    [vllm]="vLLM"
    [sglang]="SGLang"
    [nemo]="NeMo"
    [nemo-curator]="NeMo Curator"
    [pytorch]="PyTorch"
    [axolotl]="Axolotl"
)

# Hugging Face dataset with the built images, at <container>/<SIF_NAME>.
HF_REPO="ellamind/containers"

# container_config NAME: validates NAME and sets CONTAINER_NAME, TAG (from the
# environment or the default), DOCKER_IMAGE, SIF_PREFIX, DISPLAY_NAME, SIF_NAME.
container_config() {
    if [[ $# -lt 1 || ! -v "DEFAULT_TAGS[${1:-}]" ]]; then
        [[ $# -ge 1 ]] && echo "Error: Unknown container '$1'" >&2
        echo "Usage: [TAG=version] $0 <container_name>" >&2
        echo "Available containers:" >&2
        for name in "${!DEFAULT_TAGS[@]}"; do
            echo "  - $name (default: ${DEFAULT_TAGS[$name]})" >&2
        done
        exit 1
    fi
    CONTAINER_NAME="$1"
    TAG="${TAG:-${DEFAULT_TAGS[$CONTAINER_NAME]}}"
    DOCKER_IMAGE="${DOCKER_IMAGES[$CONTAINER_NAME]}"
    SIF_PREFIX="${SIF_PREFIXES[$CONTAINER_NAME]}"
    DISPLAY_NAME="${DISPLAY_NAMES[$CONTAINER_NAME]}"
    SIF_NAME="${SIF_PREFIX}_${TAG}.sif"
}
