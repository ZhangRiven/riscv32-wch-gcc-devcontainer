#-------------------------------------------------------------------------------
# WCH-IC RISC-V Toolchain Devcontainer
# Copyright © 2023 islandcontroller and contributors
#-------------------------------------------------------------------------------

# Base image: Ubuntu Dev Container
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Root user for setup
USER root

# Setup dir for packages installation
WORKDIR /tmp

#-------------------------------------------------------------------------------
# 合并所有 RUN 命令，减少层数并清理临时文件
#-------------------------------------------------------------------------------
RUN set -eux; \
    \
    # 1. 安装基础依赖 (保留原包列表)
    apt-get update && \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*; \
    \
    # 2. ninja
    wget https://github.com/ninja-build/ninja/releases/latest/download/ninja-linux.zip && \
    unzip ninja-linux.zip && \
    mv ninja /usr/local/bin/ && \
    chmod +x /usr/local/bin/ninja && \
    rm -f ninja-linux.zip; \
    \
    # 3. libpython3.8.so.1.0 (编译并仅复制动态库，删除源码)
    wget https://www.python.org/ftp/python/3.8.20/Python-3.8.20.tgz && \
    tar -xzf Python-3.8.20.tgz && \
    (cd Python-3.8.20 && \
        ./configure --enable-shared --prefix=/opt/python3.8 && \
        make -j $(nproc) && \
        cp libpython3.8.so.1.0 /usr/local/lib/ \
    ) && \
    rm -rf Python-3.8.20.tgz Python-3.8.20; \
    \
    # 4. yazi (添加源并安装，已自带 apt 清理)
    curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | \
        tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' | \
        tee /etc/apt/sources.list.d/yazi.list >/dev/null && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends yazi && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*; \
    \
    # 5. CMake (下载、校验、安装、删除压缩包)
    CMAKE_VERSION=4.4.2 && \
    CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-x86_64.tar.gz" && \
    CMAKE_HASH="3ada9a3f5d8a85413579bdd0ea6aa8e8da86efdd6d15c91a1afa517f2021956c" && \
    curl -sLO ${CMAKE_URL} && \
    echo "${CMAKE_HASH} $(basename ${CMAKE_URL})" | sha256sum -c - && \
    tar -xf $(basename "${CMAKE_URL}") -C /usr --strip-components=1 && \
    rm $(basename "${CMAKE_URL}"); \
    \
    # 6. .NET 6 Runtime (仅复制脚本，无额外临时文件)
    DOTNET_INSTALL_DIR="/opt/dotnet" && \
    # 脚本由后续 COPY 提供，此处无需操作
    \
    # 7. Mounriver Toolchain & Debugger
    MOUNRIVER_VERSION=2.5.0 && \
    MOUNRIVER_URL="https://github.com/ZhangRiven/MRS_Linux/releases/download/v2.5.0/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz" && \
    MOUNRIVER_MD5="b2dcd07209b17d214723181fdfa8098b" && \
    MOUNRIVER_OPENOCD_INSTALL_DIR="/opt/openocd" && \
    MOUNRIVER_TOOLCHAIN_INSTALL_DIR="/opt/gcc-riscv-none-elf" && \
    MOUNRIVER_RULES_INSTALL_DIR="/opt/wch/rules" && \
    MOUNRIVER_FIRMWARE_INSTALL_DIR="/opt/wch/firmware" && \
    MOUNRIVER_SVD_INSTALL_DIR="/opt/wch/svd" && \
    curl -sLO ${MOUNRIVER_URL} && \
    mkdir -p ${MOUNRIVER_RULES_INSTALL_DIR} && \
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
    rm -rf $MOUNRIVER_TMP; \
    # 修复 openocd 权限
    chmod +x ${MOUNRIVER_OPENOCD_INSTALL_DIR}/bin/openocd; \
    # 创建符号链接以修正命名
    mkdir -p ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin && \
    for i in $(ls ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/wch/bin/riscv32-wch-elf-*); do \
        k=$(echo "$(basename $i)" | sed s/wch/none/g | sed s/riscv32-/riscv-/g); \
        ln -s ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/wch/bin/$(basename $i) ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin/$k; \
    done; \
    # 链接 SVD 文件
    ln -s -t ${MOUNRIVER_SVD_INSTALL_DIR}/../ $(ls ${MOUNRIVER_SVD_INSTALL_DIR}/*.svd); \
    # 旧工具链兼容脚本 (保留原逻辑)
    MOUNRIVER_LEGACY_TOOLCHAIN_INSTALL_DIR="/opt/gcc-riscv-none-embed" && \
    for i in $(ls ${MOUNRIVER_TOOLCHAIN_INSTALL_DIR}/bin/riscv-none-elf-*); do \
        k=$(echo "$i" | sed s/-elf/-embed/g); \
        ln -s ${MOUNRIVER_LEGACY_TOOLCHAIN_INSTALL_DIR}/bin/path-info.sh $k; \
    done; \
    # 环境变量设置 (保留原 ENV，此处不重复)
    \
    # 8. ISP 烧录工具 wchisp
    ISPTOOL_VERSION=0.3.0 && \
    ISPTOOL_URL="https://github.com/ch32-rs/wchisp/releases/download/v${ISPTOOL_VERSION}/wchisp-v${ISPTOOL_VERSION}-linux-x64.tar.gz" && \
    ISPTOOL_HASH="67e3d4eb0ffd3cc610d8927e3c3f452e2110531a3f14405dcaef87df219f200d" && \
    ISPTOOL_INSTALL_DIR="/opt/wchisp" && \
    curl -sLO ${ISPTOOL_URL} && \
    mkdir -p ${ISPTOOL_INSTALL_DIR} && \
    echo "${ISPTOOL_HASH} $(basename ${ISPTOOL_URL})" | sha256sum -c - && \
    tar -xf $(basename ${ISPTOOL_URL}) -C ${ISPTOOL_INSTALL_DIR} --strip-components=1 && \
    rm -rf $(basename ${ISPTOOL_URL}); \
    \
    # 9. CH32X035 PIOC 汇编器 (wasm53b)
    WASM53B_COMMIT="3c09f65938122733a0af728c30999bac51a9abbf" && \
    WASM53B_URL="https://github.com/openwch/ch32x035/raw/${WASM53B_COMMIT}/EVT/EXAM/PIOC/Tool_Manual/Tool/WASM53B.EXE" && \
    WASM53B_MD5="52567df6cbdeb724d2a3cf1a40122ee7" && \
    WASM53B_INSTALL_DIR="/opt/wch/wasm53b" && \
    mkdir -p ${WASM53B_INSTALL_DIR} && \
    curl -sLO ${WASM53B_URL} && \
    echo "${WASM53B_MD5} $(basename ${WASM53B_URL})" | md5sum -c - && \
    mv $(basename ${WASM53B_URL}) ${WASM53B_INSTALL_DIR}; \
    # 注意：COPY wasm53b 会在构建时复制本地文件，此处保留
    \
    # 10. 目标烧录工具 wlink
    FLASHTOOL_VERSION=0.1.2 && \
    FLASHTOOL_URL="https://github.com/ch32-rs/wlink/releases/download/v${FLASHTOOL_VERSION}/wlink-v${FLASHTOOL_VERSION}-linux-x64.tar.gz" && \
    FLASHTOOL_HASH="f8f1fba2436694116fe2cf16b1572e92d116c4acd921bf12fbc0ca5bf63824bf" && \
    FLASHTOOL_INSTALL_DIR="/opt/wlink" && \
    curl -sLO ${FLASHTOOL_URL} && \
    mkdir -p ${FLASHTOOL_INSTALL_DIR} && \
    echo "${FLASHTOOL_HASH} $(basename ${FLASHTOOL_URL})" | sha256sum -c - && \
    tar -xf $(basename ${FLASHTOOL_URL}) -C ${FLASHTOOL_INSTALL_DIR} --strip-components=1 && \
    rm -rf $(basename ${FLASHTOOL_URL}); \
    \
    # 11. Devcontainer 辅助脚本 (仅复制，后续由 COPY 完成)
    # 此部分无临时文件

#-------------------------------------------------------------------------------
# 复制剩余文件 (这些 COPY 指令保持不变)
#-------------------------------------------------------------------------------
# .NET 信息脚本
ADD dotnet-info.sh /opt/dotnet/
RUN ln -s /opt/dotnet/dotnet-info.sh /opt/dotnet/dotnet
ENV PATH=$PATH:/opt/dotnet

# Mounriver 工具链 cmake 配置
COPY gcc-riscv-none-elf.cmake /opt/gcc-riscv-none-elf/
ENV PATH=$PATH:/opt/gcc-riscv-none-elf/bin:/opt/openocd/bin

# 旧工具链路径脚本 (保留)
COPY path-info.sh /opt/gcc-riscv-none-embed/bin/path-info.sh
ENV MOUNRIVER_TOOLCHAIN_INSTALL_DIR=/opt/gcc-riscv-none-elf

# 烧录工具环境变量
ENV PATH=$PATH:/opt/wchisp:/opt/wch/wasm53b:/opt/wlink

# Devcontainer 实用工具
ARG UTILS_INSTALL_DIR="/opt/devcontainer/"
COPY setup-devcontainer ${UTILS_INSTALL_DIR}/bin/
COPY install-rules ${UTILS_INSTALL_DIR}
COPY cmake-tools-kits.json ${UTILS_INSTALL_DIR}
ENV PATH=$PATH:${UTILS_INSTALL_DIR}/bin

#-------------------------------------------------------------------------------
# 用户设置
#-------------------------------------------------------------------------------
# 添加 plugdev 组供非 root 调试
RUN usermod -aG plugdev,dialout vscode

USER vscode

VOLUME [ "/workspaces" ]
WORKDIR /workspaces
