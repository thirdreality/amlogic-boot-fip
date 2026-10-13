# amlogic-boot-tools

[English](README.md) | 简体中文

用于 ThirdReality Amlogic A113X（axg）板卡、基于 Armbian 构建的启动工具集：

- `fip/`  —— FIP 固件 blob，用于把主线 u-boot（BL33）签名打包成可启动的
  `u-boot.bin`。在编译 u-boot 阶段使用。
- `burn/` —— 把构建好的 Armbian `.img` 转换为 Amlogic USB Burning Tool
  烧录镜像（`*.burn.img`）。在镜像构建完成后使用。

两部分都来自同一次 Amlogic OpenLinux buildroot SDK 2025r1 的编译产物。

## 整体流程

```
主线 u-boot.bin (BL33)
        │  fip/build-fip.sh <board>
        ▼
签名后的 u-boot.bin ──► Armbian 构建 ──► Armbian .img
                                              │  burn/convert.sh
                                              ▼
                                   *.burn.img（USB Burning Tool 烧录）
```

## 支持的板卡

| 板卡                                  | DDR                                   | `fip/`   | `burn/loaders/` | `amlogic-dt-id` |
|---------------------------------------|---------------------------------------|----------|-----------------|-----------------|
| HubV3（MB0.3）、HubV3B                | 1 颗 DDR4，16bit，1 rank，2GB @ 1200MHz | `hubv3`  | `hubv3`         | `axg_hubv3_v1`  |
| HubV3L（LinuxBox-Lite MB0.5）、HubV3A | 2 颗 DDR3，16bit，2 rank，1GB @ 912MHz  | `hubv3l` | `hubv3l`        | `axg_hubv3l_v1` |

`hubv3` 与 `hubv3l` 两个 FIP 目录只有 `acs.bin`（DDR 参数）不同。不要混用：
bl2 的 DDR 自动探测无法覆盖 HubV3L 的双 rank 布局。

## fip/

### 用法

需要在 `fip/` 目录下执行（脚本按当前目录查找板卡子目录）：

```
cd fip
./build-fip.sh hubv3 /path/to/u-boot/u-boot.bin my-output-dir
```

输出文件：`u-boot.bin`、`u-boot.bin.sd.bin`、`u-boot.bin.usb.bl2`、
`u-boot.bin.usb.tpl`。

系统依赖：x86-64 Linux（或 qemu-x86_64）、python3、sh、make、readlink、
mktemp、cat、dd。非 x86-64 主机上，`axg.inc` 会自动通过 `qemu-x86_64` 运行
`aml_encrypt_axg`。

### 打包过程

`fip/axg.inc`（由各板卡的 `Makefile` 引入）依次完成：

1. `blx_fix.sh` 将 `bl30.bin` 与 `bl301.bin` 拼接为 `bl30_new.bin`；
2. `acs_tool.py` 把 `acs.bin`（DDR 参数）注入 `bl2.bin`，再与 `bl21.bin`
   拼接为 `bl2_new.bin`；
3. `aml_encrypt_axg` 分别对 bl2 / bl30 / bl31 / bl33 做签名封装，最后用
   `--bootmk` 合成最终的 `u-boot.bin`。

### 固件来源

取自 SDK 编译目录 `fip/_tmp/`，对应配置
`axg_hubv3_a64_k54_release` / `axg_hubv3l_a64_k54_release`（u-boot 板卡名
`axg_hubv3_v1` / `axg_hubv3l_v1`）：

| 文件        | 来源                                 | 版本                      |
|-------------|--------------------------------------|---------------------------|
| `bl2.bin`   | SDK `bl2/bin/axg`                    | g226aefb1，2025-08-26     |
| `bl30.bin`  | SDK `bl30/bin/axg`                   | axg_v1.1.3545-2c4752ec29  |
| `bl31.img`  | SDK `bl31/bl31_1.3/bin/axg`          | v1.3.2(release):9593a7478 |
| `acs.bin`   | 由 `axg_hubv3*_v1.h` DDR 配置编译     | 每块板不同                |
| `bl301.bin` | 由 SDK 板级 `scp_task` 编译           | 两块板相同                |
| `bl21.bin`  | 由 SDK 板级固件编译                   | 两块板相同                |

`aml_encrypt_axg`、`acs_tool.py`、`blx_fix.sh` 和 `Makefile` 与上游
[LibreELEC/amlogic-boot-fip](https://github.com/LibreELEC/amlogic-boot-fip)
保持一致（`aml_encrypt_axg` 与 SDK 自带版本完全相同）。

与 SDK 输出一致，这些板卡不打包 BL32（OP-TEE）。
不包含任何加密 / efuse 相关产物；这些 blob 仅适用于未开启安全启动的芯片。

## burn/

### 用法

```
OUTPUT_DIR=out burn/convert.sh <image> <v3|v3a|v3b|v3l> armbian [compress] <u-boot.bin>
```

| 参数           | 说明                                                       |
|----------------|------------------------------------------------------------|
| `<image>`      | 输入镜像，支持 `.img` 或 `.img.xz`                          |
| `v3`/`v3b`     | 使用 `hubv3` 加载器，对应 DTS `trhub-v3` / `trhub-v3b`      |
| `v3l`/`v3a`    | 使用 `hubv3l` 加载器，对应 DTS `trhub-v3l` / `trhub-v3a`    |
| `armbian`      | 分区表类型（目前仅支持 `armbian`）                          |
| `compress`     | 传 `compress` 时输出为 zip，否则传其他值（如 `no`）         |
| `<u-boot.bin>` | 写入 eMMC 的主线 u-boot（即 Armbian 的 `u-boot.nosd.bin`）  |

输出写入 `$OUTPUT_DIR`，默认 `./output`。任一步骤失败时脚本以非零状态退出。

系统依赖：bash、cpp、dtc、cc、fdisk、dd、zip、xzcat；打包工具是 32 位 x86
静态二进制。

### 目录结构

| 路径 | 用途 |
|---|---|
| `convert.sh`、`lib.sh` | 转换脚本 |
| `loaders/<board>/DDR.USB`、`UBOOT.USB` | USB 烧录加载器（只在内存中运行） |
| `loaders/<board>/platform.conf` | Amlogic 平台参数，与 SDK `upgrade-axg/` 相同 |
| `image.armbian.cfg` | 打包工具的文件清单 |
| `dts/` | 用于生成 `_aml_dtb` 分区的 DTS，以及 `partition_arm.dtsi` |
| `dtbtools/dtbTool.c` | 把 DTB 打包成 `_aml_dtb.PARTITION` |
| `tools/aml_image_v2_packer_new` | Amlogic 镜像打包工具，与 SDK 自带版本相同 |

### 转换过程

1. 用 `cpp` + `dtc` 编译所选板卡的 DTS（已包含分区表）；
2. 用 `fdisk` 读取输入镜像的分区表，按分区切出 `part-1.img`（boot）、
   `part-2.img`（rootfs）；
3. 现场编译 `dtbTool` 并生成 `_aml_dtb.PARTITION`；
4. 拷入 `u-boot.bin`、USB 加载器与 `platform.conf`，由
   `aml_image_v2_packer_new` 按 `image.armbian.cfg` 打包成 `*.burn.img`。

### 分区布局

`image.armbian.cfg` 是打包配置，对应的分区表是 `dts/partition_arm.dtsi`：
独立的 128 MiB `boot`（part-1）加 `rootfs`（part-2，占满剩余空间）。boot
分区大小必须与 LinuxBox 中 `config/sources/families/trhub.conf` 的
`BOOTSIZE` 一致。

### USB 加载器

`loaders/*/DDR.USB` 与 `UBOOT.USB` 是 SDK 厂商 u-boot（2015.01）针对板卡
`axg_hubv3_v1` / `axg_hubv3l_v1` 编译出的 `u-boot.bin.usb.bl2` 和
`u-boot.bin.usb.tpl`。该 u-boot 实现了 Amlogic USB 烧录协议，而主线 u-boot
没有实现；它只在烧录期间于内存中运行，最终写入 eMMC 的引导程序是主线的
`<u-boot.bin>`。

其 `checkhw()` 中的名称必须与 `dts/` 里的 `amlogic-dt-id` 一致，并且必须恰好
由三段 `_` 分隔的字段组成，因为 `dtbtools/dtbTool.c` 只解析
`soc_platform_variant` 格式。

如需重新生成，在 SDK 中编译对应板卡的 u-boot（docker 命令见 SDK 的
`README_HUBV3.MD`），然后拷贝：

```
make -C output/axg_hubv3_a64_k54_release  uboot-dirclean uboot
make -C output/axg_hubv3l_a64_k54_release uboot-dirclean uboot

cp output/axg_hubv3_a64_k54_release/images/u-boot.bin.usb.bl2  burn/loaders/hubv3/DDR.USB
cp output/axg_hubv3_a64_k54_release/images/u-boot.bin.usb.tpl  burn/loaders/hubv3/UBOOT.USB
cp output/axg_hubv3l_a64_k54_release/images/u-boot.bin.usb.bl2 burn/loaders/hubv3l/DDR.USB
cp output/axg_hubv3l_a64_k54_release/images/u-boot.bin.usb.tpl burn/loaders/hubv3l/UBOOT.USB
```

用 `strings UBOOT.USB | grep axg_hubv3` 确认其中的 dt-id 符合预期。

## 致谢

见 [CREDITS.md](CREDITS.md)。
