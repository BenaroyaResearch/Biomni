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

RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    curl \
    wget \
    ca-certificates \
    zlib1g-dev \
    libbz2-dev \
    liblzma-dev \
    libncurses5-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -s /bin/bash biomni && \
    chown -R biomni:biomni /app /opt

USER biomni

# Install Miniforge for x86_64 (uses conda-forge as default channel)
RUN wget --progress=dot:giga https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh && \
    bash /tmp/miniforge.sh -b -p /opt/conda && \
    rm /tmp/miniforge.sh

ENV PATH=/opt/conda/bin:$PATH

# Create the conda environment (COPYed separately so this layer is only
# invalidated when environment.yml changes, not when source code changes)
COPY --chown=biomni:biomni biomni_env/environment.yml /tmp/environment.yml
RUN conda env create -f /tmp/environment.yml && rm /tmp/environment.yml

# Install openpyxl via conda before pip installations
RUN conda run -n biomni_e1 conda install -y conda-forge::openpyxl

# Install additional LLM / UI dependencies
SHELL ["conda", "run", "-n", "biomni_e1", "/bin/bash", "-c"]
RUN pip install langchain-openai langchain-anthropic langchain-ollama \
    'gradio==5.39.0' 'gradio-client==1.11.0'

# Install R and DESeq2 into the biomni_e1 conda environment
SHELL ["/bin/sh", "-c"]
RUN conda run -n biomni_e1 conda install -y -c conda-forge -c bioconda r-base bioconductor-deseq2

ENV PATH=/opt/conda/envs/biomni_e1/bin:$PATH
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

SHELL ["conda", "run", "-n", "biomni_e1", "/bin/bash", "-c"]
RUN pip install -e .

SHELL ["/bin/sh", "-c"]
ENV PATH=/opt/conda/envs/biomni_e1/bin:/app/biomni_tools/bin:$PATH

# Expose Gradio port
EXPOSE 7860

# Default command - launches Gradio demo
CMD ["conda", "run", "--no-capture-output", "-n", "biomni_e1", "python", "-c", "from biomni.agent import A1; agent = A1(path='/app/data'); agent.launch_gradio_demo(server_name='0.0.0.0', require_verification=True)"]