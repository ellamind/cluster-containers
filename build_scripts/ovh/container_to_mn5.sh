#!/bin/bash
# =============================================================================
# Put a catalog container into the MN5 container cache, from the OVH proxy box
# (ovh-proxy-1).
# Usage: [TAG=version] container-to-mn5 <container_name>
# Example: TAG=mistral-large-4 container-to-mn5 sglang
#
# Target: /gpfs/scratch/ehpc532/containers/<container>/<prefix>_<tag>.sif
# (CACHE overrides the folder), the same layout as the HF dataset.
#   - in the cache already: prints the path, does nothing;
#   - on the HF dataset: downloads it and copies it to MN5;
#   - nowhere yet: builds it, uploads it to the HF dataset, copies it to MN5.
# The copy is checked by sha256 on MN5 and left group-readable (ehpc532).
#
# Installed by the proxy playbook (model-factory: infra/proxy) as
# /usr/local/bin/container-to-mn5. Needs the `mn5` ssh alias the playbook
# sets up. Hugging Face token: HF_TOKEN if set, else the shared one the
# playbook puts in /etc/container-to-mn5/hf-token (write access to the dataset).
#
# The box's main job is the MN5 proxy, so the build stays small: squashing uses
# BUILD_CPUS cores (default 8 of 16), at nice 19 and idle I/O priority, and the
# whole run holds the box's transfer lock (shared with hf-to-mn5).
# Disk: about 2.5 x the image's download size while it builds.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/../containers.sh"
container_config "$@"

HF_PATH="${CONTAINER_NAME}/${SIF_NAME}"
DEST="${CACHE:-/gpfs/scratch/ehpc532/containers}/${HF_PATH}"
HOST=mn5
HF=(uvx --quiet --from huggingface_hub==2.4.0 hf)
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=60 -o ServerAliveInterval=30)
q=$(printf %q "$DEST")
log() { echo "$(date +%T) $*"; }

if "${SSH[@]}" "$HOST" "test -e $q"; then
    log "in the MN5 cache already: $DEST"
    exit 0
fi

TOKEN_FILE=/etc/container-to-mn5/hf-token
if [[ -z ${HF_TOKEN:-} && -r $TOKEN_FILE ]]; then
    HF_TOKEN=$(<"$TOKEN_FILE")
    export HF_TOKEN
fi

ON_HF=0
curl -sfIL -o /dev/null "https://huggingface.co/datasets/${HF_REPO}/resolve/main/${HF_PATH}" && ON_HF=1
if [[ $ON_HF == 0 && -z ${HF_TOKEN:-} ]]; then
    echo "not on ${HF_REPO} yet, and no Hugging Face token to publish a build:" >&2
    echo "$TOKEN_FILE is missing or unreadable (proxy playbook), and HF_TOKEN is not set" >&2
    exit 1
fi

LOCK=/var/lib/mn5-transfer.lock
if [[ -e $LOCK ]]; then
    exec 9<"$LOCK"
    if ! flock -n 9; then
        log "another transfer to MN5 runs on this box: queued, starts when it ends"
        flock 9
    fi
fi

mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
WORK=$(mktemp -d "${XDG_CACHE_HOME:-$HOME/.cache}/container-to-mn5.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
SIF="$WORK/${HF_PATH}"

if [[ $ON_HF == 1 ]]; then
    log "download ${HF_REPO}/${HF_PATH}"
    HF_XET_CHUNK_CACHE_SIZE_BYTES=0 "${HF[@]}" download "$HF_REPO" "$HF_PATH" \
        --repo-type dataset --local-dir "$WORK" >/dev/null
else
    export APPTAINER_TMPDIR=$WORK/tmp APPTAINER_CACHEDIR=$WORK/cache
    mkdir -p "$APPTAINER_TMPDIR" "$APPTAINER_CACHEDIR" "$(dirname "$SIF")"
    log "build ${DISPLAY_NAME}: docker://${DOCKER_IMAGE}:${TAG} (squash on ${BUILD_CPUS:-8} cores)"
    nice -n 19 ionice -c 3 apptainer build --mksquashfs-args "-processors ${BUILD_CPUS:-8}" \
        "$SIF" "docker://${DOCKER_IMAGE}:${TAG}"
    log "upload $(du -h "$SIF" | cut -f1) to ${HF_REPO}/${HF_PATH}"
    "${HF[@]}" upload "$HF_REPO" "$SIF" "$HF_PATH" --repo-type dataset \
        --commit-message "Add ${HF_PATH} (${DOCKER_IMAGE}:${TAG}, built on ovh-proxy-1)" >/dev/null
fi
SUM=$(sha256sum "$SIF" | cut -c1-64)

log "copy $(du -h "$SIF" | cut -f1) to $HOST:$DEST"
"${SSH[@]}" "$HOST" "umask 002 && mkdir -p \"\$(dirname $q)\""
mscp-mn5 -q "$SIF" "$HOST:$DEST.part"
REMOTE=$("${SSH[@]}" "$HOST" "sha256sum $q.part | cut -c1-64")
[[ $REMOTE == "$SUM" ]] \
    || { echo "sha256 differs (box $SUM, MN5 $REMOTE); $DEST.part left on MN5" >&2; exit 1; }
"${SSH[@]}" "$HOST" "chmod 664 $q.part && mv $q.part $q"
log "done: $DEST (sha256 $SUM)"
