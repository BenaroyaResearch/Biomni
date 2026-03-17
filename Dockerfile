# Multi-stage Dockerfile shared by devcontainers and CI/production.
# Note: Built for x86_64/amd64 as many bioinformatics tools (including openmm) don't support ARM64
#
# Stages:
#   base        – heavy shared setup (conda env, pip deps, R)
#   devcontainer– adds sudo for the dev user; code is bind-mounted at runtime
#   production  – clones the repo, installs the package, exposes the Gradio port

# =============================================================================
# base – shared by all downstream stages
# =============================================================================
FROM --platform=linux/amd64 ubuntu:22.04 AS base

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    curl \
    wget \
    ca-certificates \
    zlib1g-dev \
    libpng-dev \
    libbz2-dev \
    liblzma-dev \
    libncurses5-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set locale environment variables to prevent R warnings
# C.UTF-8 is available by default in Ubuntu
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN useradd -m -u 1000 -s /bin/bash biomni && \
    chown -R biomni:biomni /app /opt

USER biomni

# Install Miniforge for x86_64 (uses conda-forge as default channel)
RUN wget --progress=dot:giga https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh && \
    bash /tmp/miniforge.sh -b -p /opt/conda && \
    rm /tmp/miniforge.sh

ENV PATH=/opt/conda/bin:$PATH

# Create the conda environment in three layers so each stays under Docker
# Desktop's default 20 GiB BuildKit cache limit.
# Layer 1 – conda packages (R, bioinformatics CLI tools, etc.)
COPY --chown=biomni:biomni biomni_env/environment_conda.yml /tmp/environment_conda.yml
RUN conda env create -f /tmp/environment_conda.yml && \
    conda clean -afy && \
    rm /tmp/environment_conda.yml

# Layer 2a – pip packages (core / lightweight)
COPY --chown=biomni:biomni biomni_env/requirements.txt /tmp/requirements.txt
RUN conda run -n biomni_e1 pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Layer 2b – pip packages (heavy ML / bioinformatics)
COPY --chown=biomni:biomni biomni_env/requirements2.txt /tmp/requirements2.txt
RUN conda run -n biomni_e1 pip install --no-cache-dir -r /tmp/requirements2.txt && \
    rm /tmp/requirements2.txt

ENV PATH=/opt/conda/envs/biomni_e1/bin:/app/biomni_tools/bin:$PATH
ENV CONDA_DEFAULT_ENV=biomni_e1

RUN mkdir -p /app/data

# =============================================================================
# devcontainer – extends base with sudo; code is bind-mounted at /workspace
# postCreateCommand in devcontainer.json runs: pip install -e /workspace
# =============================================================================
FROM base AS devcontainer

USER root
RUN apt-get update && apt-get install -y sudo && rm -rf /var/lib/apt/lists/* && \
    echo "biomni ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER biomni

# =============================================================================
# production – clones the repo and installs the package for CI / deployment
# =============================================================================
FROM base AS production

COPY --chown=biomni:biomni . .

RUN conda run -n biomni_e1 pip install -e .

# Expose Gradio port
EXPOSE 7860

# Default command - launches Gradio demo
CMD ["conda", "run", "--no-capture-output", "-n", "biomni_e1", "python", "-c", "from biomni.agent import A1; agent = A1(path='/app/data'); agent.launch_gradio_demo(server_name='0.0.0.0', require_verification=True)"]