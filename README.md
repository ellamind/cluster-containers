# cluster-containers

Apptainer/Singularity container images for HPC clusters.

## Available Containers

| Container | Version | Image Path | Docker Source |
|-----------|---------|------------|---------------|
| vLLM | v0.21.0-cu129 | `containers/vllm/vllm-openai_v0.21.0-cu129.sif` | `vllm/vllm-openai` |
| vLLM | v0.14.1 | `containers/vllm/vllm-openai_v0.14.1.sif` | `vllm/vllm-openai` |
| vLLM | v0.13.0 | `containers/vllm/vllm-openai_v0.13.0.sif` | `vllm/vllm-openai` |
| SGLang | v0.5.12-cu129 | `containers/sglang/sglang_v0.5.12-cu129.sif` | `lmsysorg/sglang` |
| SGLang | v0.5.7 | `containers/sglang/sglang_v0.5.7.sif` | `lmsysorg/sglang` |
| NeMo | 26.04 | `containers/nemo/nemo_26.04.sif` | `nvcr.io/nvidia/nemo` |
| NeMo | 25.11.nemotron_3_nano | `containers/nemo/nemo_25.11.nemotron_3_nano.sif` | `nvcr.io/nvidia/nemo` |
| NeMo Curator | 26.02 | `containers/nemo-curator/nemo-curator_26.02.sif` | `nvcr.io/nvidia/nemo-curator` |
| PyTorch | 26.01-py3 | `containers/pytorch/pytorch_26.01-py3.sif` | `nvcr.io/nvidia/pytorch` |
| Axolotl | main-py3.12-cu129-2.9.1 | `containers/axolotl/axolotl_main-py3.12-cu129-2.9.1.sif` | `axolotlai/axolotl` |

## Downloading

Pre-built images are available on Hugging Face at [ellamind/containers](https://huggingface.co/datasets/ellamind/containers).

```bash
# Download all containers
hf download ellamind/containers --repo-type dataset --local-dir containers

# Download specific container
hf download ellamind/containers vllm/vllm-openai_v0.14.1.sif --repo-type dataset --local-dir containers

# Using wget
mkdir -p containers/vllm
wget -P containers/vllm https://huggingface.co/datasets/ellamind/containers/resolve/main/vllm/vllm-openai_v0.14.1.sif
```

## Building

Build scripts are in `./build_scripts`. We currently build containers on Leonardo using the budget free partition `lrd_all_serial`.

```bash
# Build with default version
./build_scripts/leonardo/build_container.sh <container_name>

# Build with specific version
TAG=v0.14.1 ./build_scripts/leonardo/build_container.sh vllm
```

Available containers: `vllm`, `sglang`, `nemo`, `nemo-curator`, `pytorch`, `axolotl`

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
