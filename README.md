# cluster-containers

Apptainer/Singularity container images for HPC clusters. Including build instructions and usage examples.

## Downloading Containers

Pre-built container images are available on Hugging Face at [ellamind/containers](https://huggingface.co/datasets/ellamind/containers). You can download them using the `hf` cli:

### Download All Containers

```bash
hf download ellamind/containers --repo-type dataset --local-dir containers
```

### Download Specific Container

```bash
hf download ellamind/containers vllm/vllm-openai_v0.14.1.sif --repo-type dataset --local-dir containers
```

### Using wget

```bash
mkdir -p containers/vllm
wget -P containers/vllm https://huggingface.co/datasets/ellamind/containers/resolve/main/vllm/vllm-openai_v0.14.1.sif
```

## vLLM

### Available Images

| Version | Image Path |
|---------|------------|
| v0.14.1 | `containers/vllm/vllm-openai_v0.14.1.sif` |
| v0.13.0 | `containers/vllm/vllm-openai_v0.13.0.sif` |



### Running

Run the vLLM OpenAI-compatible server on Leonardo:

```bash
singularity exec --nv --contain \
    --env HF_HUB_OFFLINE=1 \
    --home $TMPDIR \
    --bind /leonardo_scratch/fast/AIFAC_L01_028/models:/models \
    containers/vllm/vllm-openai_v0.14.1.sif \
    vllm serve /models/propella-1-4b \
        --host 0.0.0.0 \
        --port 64444
```

## SGLang

### Available Images

| Version | Image Path |
|---------|------------|
| v0.5.7 | `containers/sglang/sglang_v0.5.7.sif` |

### Running

Run the SGLang server on Leonardo:

```bash
TBD
```

## NeMo

### Available Images

| Version | Image Path |
|---------|------------|
| 25.11.nemotron_3_nano | `containers/nemo/nemo_25.11.nemotron_3_nano.sif` |

### Running

Run NeMo on Leonardo:

```bash
TBD
```

## Building Containers
Build scripts are in `./build-scripts`. For now, we build all containers on Leonardo.

For example, to build a vLLM container on Leonardo:

```bash
TAG=v0.14.1 ./build_scripts/leonardo/build_vllm.sh
```

To build an SGLang container:

```bash
TAG=v0.5.7 ./build_scripts/leonardo/build_sglang.sh
```

To build a NeMo container:

```bash
TAG=25.11.nemotron_3_nano ./build_scripts/leonardo/build_nemo.sh
```

Build logs are saved to `build_logs/<container>_build.log`.

## Uploading to Hugging Face

After building new containers,you can upload them to the HF dataset repository:

```bash
hf upload-large-folder "ellamind/containers" ./containers --repo-type dataset
```