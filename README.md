# wch-riscv-devcontainer
[![License](https://img.shields.io/github/license/islandcontroller/wch-riscv-devcontainer)](LICENSE) [![GitHub](https://shields.io/badge/github-islandcontroller%2Fwch--riscv--devcontainer-black?logo=github)](https://github.com/islandcontroller/wch-riscv-devcontainer) [![Docker Hub](https://shields.io/badge/docker-islandc%2Fwch--riscv--devcontainer-blue?logo=docker)](https://hub.docker.com/r/islandc/wch-riscv-devcontainer) ![Docker Image Version (latest semver)](https://img.shields.io/docker/v/islandc/wch-riscv-devcontainer?sort=semver) [![GitHub](https://shields.io/badge/github-ZhangRiven%2Friscv32--wch--gcc--devcontainer-black?logo=github)](https://github.com/ZhangRiven/riscv32-wch-gcc-devcontainer)

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
* [Ninja](https://ninja-build.org/) (latest)
* [ch32-rs/wchisp](https://github.com/ch32-rs/wchisp/) Version 0.3.0
* [ch32-rs/wlink](https://github.com/ch32-rs/wlink/) Version 0.1.2
* [Yazi](https://yazi-rs.github.io/) terminal file manager (latest)
* [clangd](https://clangd.llvm.org/) for C/C++ IntelliSense
* Python 3.8 shared library (`libpython3.8.so.1.0`)

## System Requirements
* VSCode [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
* [Podman](https://podman.io/) or Docker container runtime
* (WSL only) [usbipd-win](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)

## Importing the Pre-built Container Image

Container images are built automatically via GitHub Actions. Follow these steps to import the image:

1. **Download the image artifact** from the latest successful CI run:
   * Go to the repository [Actions](https://github.com/ZhangRiven/wch-riscv-devcontainer/actions) page
   * Select the latest `Docker Image CI` workflow run
   * Download the `docker-image.zip` artifact (a `.tar` file inside a zip archive)

2. **Load the image into Podman** (or Docker):
   ```sh
   # Extract the downloaded zip first, then load the tar file
   unzip docker-image.zip
   podman load -i image.tar
   ```

3. **Clear files, after rebuild devcontainer in VSCode** :
   ```sh
   rm -rf docker-image.zip image.tar
   podman system prune -a --volumes -f
   ```

## Usage
* Include this repo as `.devcontainer` in the root of your project
* Make sure the container image has been imported (see [Importing the Pre-built Container Image](#importing-the-pre-built-container-image) above)
* Connect debug probe 
  * (WSL only) attach to WSL using `usbipd attach --wsl --busid <...>`. **This needs to be completed before starting the Dev Container.**
* Select `Dev Containers: Reopen in Container`

For CMake projects:
* Upon prompt, select the `WCH RISC-V Toolchain x.x` CMake Kit. 
  * The toolchain file is located at [`/opt/gcc-riscv-none-elf/gcc-riscv-none-elf.cmake`](gcc-riscv-none-elf.cmake)
  * The CMake Kit definition for VS Code is located at [`/opt/devcontainer/cmake-tools-kits.json`](cmake-tools-kits.json)
* Run `CMake: Configure`
* Build using `CMake: Build [F7]`
* Flash using `wlink flash build/xxx.elf`
  * task.json
    ```json
    {
      // See https://go.microsoft.com/fwlink/?LinkId=733558
      // for the documentation about the tasks.json format
      "version": "2.0.0",
      "tasks": [
        {
          "label": "Build",
          "type": "shell",
          "command": "cmake",
          "args": [
            "--build",
            "${workspaceFolder}/build",
            "--config",
            "Debug",
            "--target",
            "all",
            "-j",
            "24",
            "--"
          ],
          "group": {
            "kind": "build",
            "isDefault": true
          },
          "presentation": {
            "echo": true,
            "reveal": "always"
          }
        },
        {
          "label": "Flash",
          "type": "shell",
          "command": "wlink",
          "args": [
            "flash",
            "build/CH585D.elf"
          ],
          "group": {
            "kind": "build",
            "isDefault": true
          },
          "presentation": {
            "echo": true,
            "reveal": "always"
          }
        }
      ]
    }
    ```
* Debug
  * launch.json
    ```json
    {
      "version": "0.2.0",
      "configurations": [
        {
          "name": "Debug (cppdbg)",
          "type": "cppdbg",
          "request": "launch",
          "cwd": "${workspaceFolder}",
          "program": "${workspaceFolder}/build/CH585D.elf",

          /* OpenOCD debugger */
          "debugServerPath": "openocd",
          "debugServerArgs": "-f /opt/openocd/bin/wch-riscv.cfg",
          "filterStderr": true,
          "serverStarted": "Info : Listening on port 3333 for gdb connections",
          
          /* Debugger connection */
          "MIMode": "gdb",
          "miDebuggerPath": "/opt/gcc-riscv-none-elf/bin/riscv-none-elf-gdb",
          "miDebuggerServerAddress": "localhost:3333",
          "useExtendedRemote": true,

          /* Debugger and target setup */
          "stopAtEntry": false,
          "setupCommands": [
            { "text": "-enable-pretty-printing" },
            { "text": "set mem inaccessible-by-default off" },
            { "text": "set architecture riscv:rv32" },
            { "text": "set remotetimeout unlimited" },
          ],
          "postRemoteConnectCommands": [
            { "text": "monitor reset halt" },
            { "text": "monitor [target current] configure -event gdb-detach { shutdown }" },
            { "text": "load" },
            { "text": "monitor reset halt" },
            { "text": "b main" },
            { "text": "b HardFault_Handler" },
          ],
          "launchCompleteCommand": "exec-continue",

          /* Peripheral viewer */
          "svdPath": "/opt/wch/svd/CH585.svd"
        }
      ]
    }
    ```

### CMake+IntelliSense Notes
Upon first run, an error message may appear in Line 1, Column 1. Try re-running CMake configuration, or run a build. If the file is a `.h` header file, it needs to be `#include`'d into a C module.

### UDEV Rules installation
In order to use USB debug probes within the container, some udev rules need to be installed on the **host** machine. A setup script has been provided to aid with installation.
* Run `setup-devcontainer` inside the **container**
* Close the container, and re-open the work directory on your **host**
* Run the `install-rules` script inside `.vscode/setup/` on your host machine

      cd .vscode/setup
      sudo ./install-rules

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
To access the WCH-Link serial monitor inside the devcontainer, use command: `sudo minicom -s`.

#### Troubleshooting USB permission errors
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

## Automated Build via GitHub Actions

Container images are built automatically using GitHub Actions workflows:

### Docker Image CI (`docker-image.yml`)
Triggered on every push or pull request to the `master` branch, or manually via `workflow_dispatch`.

* Builds the Docker image and exports it as a runnable tar artifact
* Uploads the `docker-image` artifact (retention: 7 days)
* Uses GitHub Actions cache for faster builds

## Building Locally

If you need to build the image locally instead of using the CI artifact:

```sh
podman build \
  -t riven/riscv32-wch-gcc-devcontainer:latest \
  -f Dockerfile \
  .
```

Or with Docker:

```sh
docker build \
  -t riven/riscv32-wch-gcc-devcontainer:latest \
  -f Dockerfile \
  .
```

The MounRiver Studio II package is downloaded automatically from the [ZhangRiven/MRS_Linux](https://github.com/ZhangRiven/MRS_Linux/releases) GitHub Releases mirror during build. If you want to use a local copy instead, modify the `MOUNRIVER_URL` ARG in the [Dockerfile](Dockerfile#L81-L83):

```dockerfile
ARG MOUNRIVER_URL="https://github.com/ZhangRiven/MRS_Linux/releases/download/v${MOUNRIVER_VERSION}/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz"
# ARG MOUNRIVER_URL="/tmp/MounRiverStudio_Linux_X64_V${MOUNRIVER_VERSION}.tar.xz"
```

Then uncomment the `COPY` line and comment out the `curl` line around line [Dockerfile](Dockerfile#L92-L99).

## Licensing

If not stated otherwise, the contents of this project are licensed under The MIT License. The full license text is provided in the [`LICENSE`](LICENSE) file.

    SPDX-License-Identifier: MIT