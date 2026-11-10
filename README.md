# cluster-containers

Apptainer/Singularity images (SIF) for our clusters, above all a cache of images for MareNostrum 5:

- [ellamind/containers](https://huggingface.co/datasets/ellamind/containers) on Hugging Face holds every built image, as `<container>/<prefix>_<tag>.sif`.
- On MN5, `/gpfs/scratch/ehpc532/containers/` holds the same files, in the same layout, for everyone in `ehpc532`. Use them from there; don't keep private copies.

Get an image onto MN5 with `container-to-mn5` on the OVH proxy box (below). It copies from the HF dataset, or builds and publishes the image first if it isn't there yet.

## Available Containers

| Container | Docker Source | File name |
|-----------|---------------|-----------|
| `vllm` | `vllm/vllm-openai` | `vllm/vllm-openai_<tag>.sif` |
| `sglang` | `lmsysorg/sglang` | `sglang/sglang_<tag>.sif` |
| `nemo` | `nvcr.io/nvidia/nemo` | `nemo/nemo_<tag>.sif` |
| `nemo-curator` | `nvcr.io/nvidia/nemo-curator` | `nemo-curator/nemo-curator_<tag>.sif` |
| `pytorch` | `nvcr.io/nvidia/pytorch` | `pytorch/pytorch_<tag>.sif` |
| `axolotl` | `axolotlai/axolotl` | `axolotl/axolotl_<tag>.sif` |

`<tag>` is the Docker tag. Tags ending in `-aarch64` are for ARM clusters (JUPITER); the others are x86_64. A new container is one line per table in `build_scripts/containers.sh`.

```bash
# Published images
curl -s 'https://huggingface.co/api/datasets/ellamind/containers/tree/main?recursive=true' \
  | jq -r '.[] | select(.path | endswith(".sif")) | .path'
# On MN5
ls /gpfs/scratch/ehpc532/containers/*/
```

## MareNostrum 5: `container-to-mn5`

MN5 has no internet; the OVH proxy box (`ovh-proxy-1`) fills the cache. Its playbook (model-factory `infra/proxy`) installs Apptainer and this repo there, and links `build_scripts/ovh/container_to_mn5.sh` as `container-to-mn5`.

```bash
# on ovh-proxy-1, as yourself; detached, so the laptop can disconnect
systemd-run --user --collect --unit sif-sglang -E TAG=mistral-large-4 container-to-mn5 sglang
journalctl --user -fu sif-sglang
# -> /gpfs/scratch/ehpc532/containers/sglang/sglang_mistral-large-4.sif
```

- In the MN5 cache already: prints the path. On the HF dataset: downloads it and copies it. Nowhere yet: builds it, uploads it to the HF dataset, then copies it.
- The copy is checked by sha256 on MN5 and is group-readable for `ehpc532`.
- Setup: your OVH user and MN5 login in the proxy playbook. It gives you the `mn5` ssh alias, and the Hugging Face token for uploads (`/etc/container-to-mn5/hf-token`, write access to `ellamind/containers`; `HF_TOKEN` overrides it).
- The box is the MN5 proxy first: the squash step uses 8 of its 16 cores (`BUILD_CPUS`), at nice 19 and idle disk priority, and one run at a time shares the box with `hf-to-mn5` (a lock). A build needs ~2.5 × the image's download size of free disk.
- The box cannot run images (Ubuntu blocks the user namespaces `apptainer exec` needs): test them on MN5 in a job.

## Downloading elsewhere

```bash
# Download all containers
hf download ellamind/containers --repo-type dataset --local-dir containers

# Download specific container
hf download ellamind/containers vllm/vllm-openai_v0.14.1.sif --repo-type dataset --local-dir containers

# Using wget
mkdir -p containers/vllm
wget -P containers/vllm https://huggingface.co/datasets/ellamind/containers/resolve/main/vllm/vllm-openai_v0.14.1.sif
```

## Building on Leonardo

Uses the budget free partition `lrd_all_serial`. Upload the result to the HF dataset (see Uploading).

```bash
# Build with default version
./build_scripts/leonardo/build_container.sh <container_name>

# Build with specific version
TAG=v0.14.1 ./build_scripts/leonardo/build_container.sh vllm
```

Build logs are saved to `build_logs/<container>_build.log`.

### Building Custom Containers from a Definition File

To extend a base container with additional packages, you can write an Apptainer definition (`.def`) file and build it on a local machine where you have `sudo`. Building from a definition file requires root privileges, which are not available on Leonardo.

Example definition file (`nemo_polars.def`):

```
Bootstrap: localimage
From: nemo_25.11.nemotron_3_nano.sif

%post
    pip install polars

%labels
    Author ellamind
    Description NeMo with polars
```

Build locally and transfer to Leonardo:

```bash
# On your local machine (requires sudo)
sudo singularity build nemo_polars.sif nemo_polars.def

# Transfer to Leonardo
scp nemo_polars.sif leonardo:$WORK/cluster-containers/containers/nemo/
```

> **Tip:** Use `Bootstrap: localimage` to build from a `.sif` file already on disk. To build from a remote Docker image instead, use `Bootstrap: docker` with `From: nvcr.io/nvidia/nemo:25.11.nemotron_3_nano`.

## Uploading

Upload built containers to the HF dataset repository:

```bash
hf upload-large-folder "ellamind/containers" ./containers --repo-type dataset
```

## Usage Examples

### vLLM

Run the vLLM OpenAI-compatible server on Leonardo:

```bash
mkdir -p $SCRATCH/tmp_home/container_tmp
singularity exec --nv \
    --env HF_HUB_OFFLINE=1 \
    --home $SCRATCH/tmp_home \
    --bind models:/models \
    --bind $SCRATCH/tmp_home/container_tmp:/tmp \
    containers/vllm/vllm-openai_v0.14.1.sif \
    vllm serve /models/Qwen/Qwen3-4B-Base \
        --host 0.0.0.0 \
        --port 64444
```
