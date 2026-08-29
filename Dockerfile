#-------------------------------------------------------------------------------
# WCH-IC RISC-V Toolchain Devcontainer
# Copyright © 2023 islandcontroller and contributors
#-------------------------------------------------------------------------------

# Base image: Ubuntu Dev Container
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Root user for setup
USER root

# Dependencies setup
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    vim \
    minicom \
    curl \
    make \
    python3-pygments \
    software-properties-common \
    tar \
    udev \
    unzip \
    usbutils \
    clangd \
    gdb-multiarch

# Setup dir for packages installation
WORKDIR /tmp

# yazi
RUN curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null
RUN echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    yazi \
    && rm -rf /var/lib/apt/lists/*


#- CMake -----------------------------------------------------------------------
ARG CMAKE_VERSION=4.4.2
ARG CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz"
ARG CMAKE_HASH="3ada9a3f5d8a85413579bdd0ea6aa8e8da86efdd6d15c91a1afa517f2021956c"

# Download and install package
RUN curl -sLO ${CMAKE_URL} && \
    echo "${CMAKE_HASH} $(basename ${CMAKE_URL})" | sha256sum -c - && \
    tar -xf $(basename "${CMAKE_URL}") -C /usr --strip-components=1 && \
    rm $(basename "${CMAKE_URL}")

#- .NET 6 Runtime --------------------------------------------------------------
ARG DOTNET_INSTALL_DIR="/opt/dotnet"

# Display warning for tools still using deprecated .NET version
ADD dotnet-info.sh ${DOTNET_INSTALL_DIR}/
RUN ln -s ${DOTNET_INSTALL_DIR}/dotnet-info.sh ${DOTNET_INSTALL_DIR}/dotnet
ENV PATH=$PATH:${DOTNET_INSTALL_DIR}

#- Mounriver Toolchain & Debugger ----------------------------------------------
ARG MOUNRIVER_VERSION=2.5.0
ARG MOUNRIVER_URL="https://github.com/ZhangRiven/MRS_Linux/releases/download/v2.5.0/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz"
# ARG MOUNRIVER_URL="/tmp/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz"
ARG MOUNRIVER_MD5="b2dcd07209b17d214723181fdfa8098b"
ARG MOUNRIVER_OPENOCD_INSTALL_DIR="/opt/openocd"
ARG MOUNRIVER_TOOLCHAIN_INSTALL_DIR="/opt/gcc-riscv-none-elf"
ARG MOUNRIVER_RULES_INSTALL_DIR="/opt/wch/rules"
ARG MOUNRIVER_FIRMWARE_INSTALL_DIR="/opt/wch/firmware"
ARG MOUNRIVER_SVD_INSTALL_DIR="/opt/wch/svd"

# Download and install package
RUN curl -sLO ${MOUNRIVER_URL}
# COPY MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz /tmp
RUN mkdir -p ${MOUNRIVER_RULES_INSTALL_DIR} && \
    mkdir -p ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR} && \
    mkdir -p ${MOUNRIVER_SVD_INSTALL_DIR} && \
    echo "${MOUNRIVER_MD5} $(basename ${MOUNRIVER_URL})" | md5sum -c - && \
    MOUNRIVER_TMP=$(mktemp -d) && \
    tar -xf $(basename "${MOUNRIVER_URL}") -C $MOUNRIVER_TMP --strip-components 1 && \
    rm $(basename "${MOUNRIVER_URL}") && \
    mv $MOUNRIVER_TMP/beforeinstall/lib* /usr/lib/ && ldconfig && \
    mv $MOUNRIVER_TMP/beforeinstall/*.rules ${MOUNRIVER_RULES_INSTALL_DIR} && \
    mv $MOUNRIVER_TMP/MRS-linux-x64/resources/app/resources/linux/components/WCH/Toolchain/RISC-V\ Embedded\ GCC15 ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/wch && \
    rm $MOUNRIVER_TMP/MRS-linux-x64/resources/app/resources/linux/components/WCH/OpenOCD/OpenOCD/bin/wch-arm.cfg && \
    mv $MOUNRIVER_TMP/MRS-linux-x64/resources/app/resources/linux/components/WCH/OpenOCD/OpenOCD ${MOUNRIVER_OPENOCD_INSTALL_DIR} && \
    mv $MOUNRIVER_TMP/MRS-linux-x64/resources/app/resources/linux/components/WCH/Others/Firmware_Link/default ${MOUNRIVER_FIRMWARE_INSTALL_DIR} && \
    for i in $(find $MOUNRIVER_TMP/MRS-linux-x64/resources/app/resources/linux/components/WCH/SDK/default/RISC-V/ -name *.svd | uniq); do mv $i ${MOUNRIVER_SVD_INSTALL_DIR}; done && \
    rm -rf $MOUNRIVER_TMP
COPY gcc-riscv-none-elf.cmake ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}
ENV PATH=$PATH:${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin:${MOUNRIVER_OPENOCD_INSTALL_DIR}/bin

# Fix broken openocd file permissions
RUN chmod +x ${MOUNRIVER_OPENOCD_INSTALL_DIR}/bin/openocd

# Workaround: link to mis-named toolchain binaries
RUN mkdir -p ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin && \
    for i in $(ls ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/wch/bin/riscv32-wch-elf-*); do k=$(echo "$(basename $i)" | sed s/wch/none/g | sed s/riscv32-/riscv-/g); ln -s ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/wch/bin/$(basename $i) ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin/$k; done

# Create links to SVD files
RUN ln -s -t ${MOUNRIVER_SVD_INSTALL_DIR}/../ $(ls ${MOUNRIVER_SVD_INSTALL_DIR}/*.svd)

# Display warning for mis-configured toolchains
ARG MOUNRIVER_LEGACY_TOOLCHAIN_INSTALL_DIR="/opt/gcc-riscv-none-embed"
COPY path-info.sh ${MOUNRIVER_LEGACY_TOOLCHAIN_INSTALL_DIR}/bin/path-info.sh
ENV MOUNRIVER_TOOLCHAIN_INSTALL_DIR=${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}
RUN for i in $(ls ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin/riscv-none-elf-*); do k=$(echo "$i" | sed s/-elf/-embed/g); ln -s ${MOUNRIVER_LEGACY_TOOLCHAIN_INSTALL_DIR}/bin/path-info.sh $k; done

#- ISP flashing tool -----------------------------------------------------------
ARG ISPTOOL_VERSION=0.3.0
ARG ISPTOOL_URL="https://github.com/ch32-rs/wchisp/releases/download/v${ISPTOOL_VERSION}/wchisp-v${ISPTOOL_VERSION}-linux-x64.tar.gz"
ARG ISPTOOL_HASH="67e3d4eb0ffd3cc610d8927e3c3f452e2110531a3f14405dcaef87df219f200d"
ARG ISPTOOL_INSTALL_DIR="/opt/wchisp"

# Download and install package; Copy firmware files
RUN curl -sLO ${ISPTOOL_URL} && \
    mkdir -p ${ISPTOOL_INSTALL_DIR} && \
    echo "${ISPTOOL_HASH} $(basename ${ISPTOOL_URL})" | sha256sum -c - && \
    tar -xf $(basename ${ISPTOOL_URL}) -C ${ISPTOOL_INSTALL_DIR} --strip-components=1 && \
    rm -rf $(basename ${ISPTOOL_URL})
ENV PATH=$PATH:${ISPTOOL_INSTALL_DIR}

#- CH32X035 PIOC assembler -----------------------------------------------------
ARG WASM53B_COMMIT="3c09f65938122733a0af728c30999bac51a9abbf"
ARG WASM53B_URL="https://github.com/openwch/ch32x035/raw/${WASM53B_COMMIT}/EVT/EXAM/PIOC/Tool_Manual/Tool/WASM53B.EXE"
ARG WASM53B_MD5="52567df6cbdeb724d2a3cf1a40122ee7"
ARG WASM53B_INSTALL_DIR="/opt/wch/wasm53b"

# Download executable, verify and copy to install dir
COPY wasm53b ${WASM53B_INSTALL_DIR}/
RUN curl -sLO ${WASM53B_URL} && \
    echo "${WASM53B_MD5} $(basename ${WASM53B_URL})" | md5sum -c - && \
    mv $(basename ${WASM53B_URL}) ${WASM53B_INSTALL_DIR}
ENV PATH=$PATH:${WASM53B_INSTALL_DIR}

#- Target flasing tool ---------------------------------------------------------
ARG FLASHTOOL_VERSION=0.1.2
ARG FLASHTOOL_URL="https://github.com/ch32-rs/wlink/releases/download/v${FLASHTOOL_VERSION}/wlink-v${FLASHTOOL_VERSION}-linux-x64.tar.gz"
ARG FLASHTOOL_HASH="f8f1fba2436694116fe2cf16b1572e92d116c4acd921bf12fbc0ca5bf63824bf"
ARG FLASHTOOL_INSTALL_DIR="/opt/wlink"

# Download and install package
RUN curl -sLO ${FLASHTOOL_URL} && \
    mkdir -p ${FLASHTOOL_INSTALL_DIR} && \
    echo "${FLASHTOOL_HASH} $(basename ${FLASHTOOL_URL})" | sha256sum -c - && \
    tar -xf $(basename ${FLASHTOOL_URL}) -C ${FLASHTOOL_INSTALL_DIR} --strip-components=1 && \
    rm -rf $(basename ${FLASHTOOL_URL})
ENV PATH=$PATH:${FLASHTOOL_INSTALL_DIR}

#- Devcontainer utilities ------------------------------------------------------
ARG UTILS_INSTALL_DIR="/opt/devcontainer/"

# Add setup files and register in path
COPY setup-devcontainer ${UTILS_INSTALL_DIR}/bin/
COPY install-rules ${UTILS_INSTALL_DIR}
COPY cmake-tools-kits.json ${UTILS_INSTALL_DIR}
ENV PATH=$PATH:${UTILS_INSTALL_DIR}/bin

#- User setup ------------------------------------------------------------------
# Add plugdev group for non-root debugger access
RUN usermod -aG plugdev,dialout vscode

USER vscode

VOLUME [ "/workspaces" ]
WORKDIR /workspaces