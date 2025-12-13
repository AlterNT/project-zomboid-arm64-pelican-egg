# Originally based off https://github.com/EthanHand/project-zomboid-docker-arm64/blob/main/Dockerfile
# An attempt was made to slim it down somewhat.

# --- Build FEX-Emu for OCI instance ---

FROM ubuntu:24.04 AS ubuntu-fex
ENV DEBIAN_FRONTEND=noninteractive

# FEX Build Dependencies
# https://wiki.fex-emu.com/index.php/Development:Setting_up_FEX#Debian.2FUbuntu_dependencies
# Probably not all necessary, but better safe than sorry.
RUN apt-get update && \
    apt-get install -y \
    git \
    cmake \
    curl \
    ninja-build \
    pkgconf \
    ccache \
    clang \
    llvm \
    lld \
    binfmt-support \
    libssl-dev \
    python3-setuptools \
    g++-x86-64-linux-gnu \
    libgcc-12-dev-i386-cross \
    libgcc-12-dev-amd64-cross \
    nasm \
    python3-clang \
    libstdc++-12-dev-i386-cross \
    libstdc++-12-dev-amd64-cross \
    libstdc++-12-dev-arm64-cross \
    squashfs-tools \
    squashfuse \
    libc-bin \
    libc6-dev-i386-amd64-cross \
    lib32stdc++-12-dev-amd64-cross \
    qtdeclarative5-dev \
    qml-module-qtquick-controls \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-dialogs

# Build and Install FEX-Emu
WORKDIR /root
RUN git clone --recurse-submodules https://github.com/FEX-Emu/FEX.git && \
    cd FEX && \
    git checkout a08a6ce5de51f5e625357ecaed46c463aa1e3c99 && \
    git submodule update --init --recursive && \
    mkdir Build && \
    cd Build && \
    CC=clang CXX=clang++ cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DUSE_LINKER=lld -DENABLE_LTO=True -DBUILD_TESTS=False -DENABLE_ASSERTIONS=False -G Ninja .. && \
    ninja && \
    ninja install

# --- Create installer image ---

FROM ubuntu-fex AS installer
ENV DEBIAN_FRONTEND=noninteractive

# Install RootFS for root user
RUN yes 1 | FEXRootFSFetcher

# --- Create runtime image ---

FROM ubuntu-fex AS runtime
ENV DEBIAN_FRONTEND=noninteractive

# Entrypoint dependencies
RUN apt-get update && \
    apt-get install -y \
    tini \
    iproute2

# Setup user and working directory
RUN useradd -m -d /home/container -s /bin/bash container
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# Install RootFS for container user
RUN yes 1 | FEXRootFSFetcher

# Setup entrypoint script
COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Enter pelican startup script
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]