# wch-riscv-devcontainer
[![License](https://img.shields.io/github/license/islandcontroller/wch-riscv-devcontainer)](LICENSE) [![GitHub](https://shields.io/badge/github-islandcontroller%2Fwch--riscv--devcontainer-black?logo=github)](https://github.com/islandcontroller/wch-riscv-devcontainer) [![Docker Hub](https://shields.io/badge/docker-islandc%2Fwch--riscv--devcontainer-blue?logo=docker)](https://hub.docker.com/r/islandc/wch-riscv-devcontainer) ![Docker Image Version (latest semver)](https://img.shields.io/docker/v/islandc/wch-riscv-devcontainer?sort=semver)

*WCH-IC RISC-V development and debugging environment inside a VSCode devcontainer.*

![Screenshot](scr.PNG)

### Packages
* [MounRiver Studio II (MRS2)](https://www.mounriver.com/download) Version 2.5.0
  * WCH-custom GNU toolchain for RISC-V Version 15.2.0
  * WCH-custom OpenOCD Version 0.11.0
  * ISP Firmware Version `v41`
  * SVD files
* [CH32X035 PIOC Assembler](https://github.com/openwch/ch32x035/tree/main/EVT/EXAM/PIOC/Tool_Manual/Tool) Version 3.1
* [CMake](https://cmake.org/download) Version 4.4.2
* [ch32-rs/wchisp](https://github.com/ch32-rs/wchisp/) Version 0.3.0
* [ch32-rs/wlink](https://github.com/ch32-rs/wlink/) Version 0.1.2

## System Requirements
* VSCode [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
* (WSL only) [usbipd-win](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)

## Usage
* Include this repo as `.devcontainer` in the root of your project
* Connect debug probe 
  * (WSL only) attach to WSL using `usbipd attach --wsl --busid <...>`. **This needs to be completed before starting the Dev Container.**
* Select `Dev Containers: Reopen in Container`

For CMake projects:
* Upon prompt, select the `WCH RISC-V Toolchain x.x` CMake Kit. 
  * The toolchain file is located at [`/opt/gcc-riscv-none-elf/gcc-riscv-none-elf.cmake`](gcc-riscv-none-elf.cmake)
  * The CMake Kit definition for VS Code is located at [`/opt/devcontainer/cmake-tools-kits.json`](cmake-tools-kits.json)
* Run `CMake: Configure`
* Build using `CMake: Build [F7]`

### CMake+IntelliSense Notes
Upon first run, an error message may appear in Line 1, Column 1. Try re-running CMake configuration, or run a build. If the file is a `.h` header file, it needs to be `#include`'d into a C module.

### UDEV Rules installation
In order to use USB debug probes within the container, some udev rules need to be installed on the **host** machine. A setup script has been provided to aid with installation.
* Run `setup-devcontainer` inside the **container**
* Close the container, and re-open the work directory on your **host**
* Run the `install-rules` script inside `.vscode/setup/` on your host machine

      cd .vscode/setup
      sudo ./install-rules


### Troubleshooting USB permission errors
If `wlink flash` fails with `failed to open device (errno 13)`, the WCH-Link is usually visible but the current host user does not have permission to open it. On distributions that do not provide the `plugdev` group by default, create the group and add the current user to it:

```sh
sudo groupadd --system plugdev 2>/dev/null || true
sudo usermod -aG plugdev "$USER"
```

Reload the rules, then unplug and reconnect the WCH-Link:

```sh
cd .vscode/setup
sudo ./install-rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

Log out and back in so the new group membership takes effect. For a temporary shell-only change, use `newgrp plugdev` instead.

Rebuild and reopen the Dev Container so the USB device mount and permissions are refreshed:

```text
Dev Containers: Rebuild and Reopen in Container
```

Verify the setup inside the container:

```sh
id
lsusb | grep -i wch
ls -l /dev/bus/usb/*/*
wlink flash build/CH585D.elf
```

The container already enables privileged access and mounts `/dev/bus/usb/` in `devcontainer.json`; no additional Docker arguments are normally required.


### WCH-Link Firmware Update
**Firmware update files** are provided in `/opt/wch/firmware/` and can be programmed using the `wchisp` utility. See the [`wchisp` GitHub repository](https://github.com/ch32-rs/wchisp/) for more information.


See the [WCH-Link User Manual](https://www.wch-ic.com/downloads/WCH-LinkUserManual_PDF.html) about updating your programmer and to determine which firmware file to use.

    wchisp flash /opt/wch/firmware/<isp-specific firmware file>

### OpenOCD Config File
Configuration files for the OpenOCD debugger are included in `/opt/openocd/bin/`. To start the debugger, run the following command inside the devcontainer terminal:

    openocd -f /opt/openocd/bin/wch-riscv.cfg

### Peripheral Description Files Notes
Peripheral description files (SVD) for RISC-V MCUs are provided in `/opt/wch/`.

### Serial Monitor
To access the WCH-Link serial monitor inside the devcontainer, use the `picocom` command as shown below:

    picocom -b <baudrate> <tty port device>

e.g. "`picocom -b 500000 /dev/ttyUSB0`".

To close the connection, press RETURN/ESC/Ctrl-C, type "`~.`" (tilde, dot) and wait for 3 seconds.

### Flashing a target with pre-built image

To flash a target with a pre-built firmware image, use the included `wlink` utility. See the [`wlink`GitHub repository](https://github.com/ch32-rs/wlink/) for more information.

    wlink flash <hexfile>

### Running PIOC (CH53x) assembler
The CH32X035 *PIOC* uses a custom CPU architecture, hence at the moment only the WCH-provided assembler can be used to build PIOC binaries.
In order to run the assembler, a 32-bit WINE installation inside the container is required (~1 GiB installation).
* Run `setup-devcontainer --install-wine` inside the container.
* Run the compiler with 

      wasm53b <asm file name>

* Convert output binary to C-array

      xxd -i <binary file name> <C source file name>

## Building
```sh
podman build \
  -t riven/riscv32-wch-gcc-devcontainer:latest \
  -f .devcontainer/Dockerfile \
  .devcontainer
```

To build the image yourself, either download the [Linux MounRiver Studio II (MRS2)](http://www.mounriver.com/download) package manually and place it in the build directory, or enable the download in the [dockerfile](Dockerfile#L59-L68):

```dockerfile
ARG MOUNRIVER_URL="http://file-oss.mounriver.com/upgrade/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz"
#ARG MOUNRIVER_URL="/tmp/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz"
...

# Download and install package
RUN curl -sLO ${MOUNRIVER_URL}
#COPY MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz /tmp
...
```

## Licensing

If not stated otherwise, the contents of this project are licensed under The MIT License. The full license text is provided in the [`LICENSE`](LICENSE) file.

    SPDX-License-Identifier: MIT