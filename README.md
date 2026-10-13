# amlogic-boot-tools

English | [简体中文](README.zh-CN.md)

Boot tooling for ThirdReality Amlogic A113X (axg) boards built with Armbian:

- `fip/`  — FIP blobs used to sign mainline u-boot (BL33) into a bootable
  `u-boot.bin`. Used at u-boot build time.
- `burn/` — converts a finished Armbian `.img` into an Amlogic USB Burning
  Tool image (`*.burn.img`). Used after the image is built.

Both sides come from the same Amlogic OpenLinux buildroot SDK 2025r1 build.

## Boards

| Board                     | DDR                                     | `fip/` | `burn/loaders/` | `amlogic-dt-id` |
|---------------------------|-----------------------------------------|--------|-----------------|-----------------|
| HubV3 (MB0.3), HubV3B     | 1x DDR4, 16bit, 1 rank, 2GB @ 1200MHz   | `hubv3`  | `hubv3`  | `axg_hubv3_v1`  |
| HubV3L (LinuxBox-Lite MB0.5), HubV3A | 2x DDR3, 16bit, 2 ranks, 1GB @ 912MHz | `hubv3l` | `hubv3l` | `axg_hubv3l_v1` |

The `hubv3` and `hubv3l` FIP directories differ only in `acs.bin` (DDR
parameters). Do not swap them: the bl2 DDR auto-detect does not cover the
HubV3L 2-rank layout.

## fip/

### Usage

Run from inside `fip/` (the script looks up the board directory relative to
the current directory):

```
cd fip
./build-fip.sh hubv3 /path/to/u-boot/u-boot.bin my-output-dir
```

Output: `u-boot.bin`, `u-boot.bin.sd.bin`, `u-boot.bin.usb.bl2`,
`u-boot.bin.usb.tpl`.

System requirements: x86-64 Linux (or qemu-x86_64), python3, sh, make,
readlink, mktemp, cat, dd.

### Origin of the blobs

Taken from the `fip/_tmp/` directory of the SDK build, configs
`axg_hubv3_a64_k54_release` / `axg_hubv3l_a64_k54_release` (u-boot boards
`axg_hubv3_v1` / `axg_hubv3l_v1`):

| File        | Source                                   | Version                         |
|-------------|------------------------------------------|---------------------------------|
| `bl2.bin`   | SDK `bl2/bin/axg`                        | g226aefb1, 2025-08-26           |
| `bl30.bin`  | SDK `bl30/bin/axg`                       | axg_v1.1.3545-2c4752ec29        |
| `bl31.img`  | SDK `bl31/bl31_1.3/bin/axg`              | v1.3.2(release):9593a7478       |
| `acs.bin`   | built from `axg_hubv3*_v1.h` DDR config  | per board                       |
| `bl301.bin` | built from SDK board `scp_task`          | same for both boards            |
| `bl21.bin`  | built from SDK board firmware            | same for both boards            |

`aml_encrypt_axg`, `acs_tool.py`, `blx_fix.sh` and `Makefile` are unchanged
from upstream [LibreELEC/amlogic-boot-fip](https://github.com/LibreELEC/amlogic-boot-fip)
(`aml_encrypt_axg` is identical to the SDK copy).

No BL32 (OP-TEE) is packaged, same as the SDK output for these boards.
No encrypted / efuse artifacts are included; these blobs are for
non-secure-boot chips only.

## burn/

### Usage

```
OUTPUT_DIR=out burn/convert.sh <image> <v3|v3a|v3b|v3l> armbian [compress] <u-boot.bin>
```

`<u-boot.bin>` is the mainline u-boot written to eMMC (Armbian's
`u-boot.nosd.bin`). Output is written to `$OUTPUT_DIR`, default `./output`.

System requirements: bash, cpp, dtc, cc, fdisk, dd, zip, xzcat; the packer is a
32-bit x86 static binary.

### Layout

| Path | Purpose |
|---|---|
| `convert.sh`, `lib.sh` | conversion script |
| `loaders/<board>/DDR.USB`, `UBOOT.USB` | USB burning loaders (run in RAM only) |
| `loaders/<board>/platform.conf` | Amlogic platform parameters, identical to SDK `upgrade-axg/` |
| `image.armbian.cfg` | packer file list |
| `dts/` | DTS used to build the `_aml_dtb` partition, plus `partition_arm.dtsi` |
| `dtbtools/dtbTool.c` | packs the DTB(s) into `_aml_dtb.PARTITION` |
| `tools/aml_image_v2_packer_new` | Amlogic packer, identical to the SDK copy |

### Partition layout

`image.armbian.cfg` is the packer config; the matching partition table is
`dts/partition_arm.dtsi`. It is a separate 128 MiB `boot` (part-1) plus
`rootfs` (part-2); the boot size must match `BOOTSIZE` in LinuxBox
`config/sources/families/trhub.conf`.

### USB loaders

`loaders/*/DDR.USB` and `UBOOT.USB` are `u-boot.bin.usb.bl2` and
`u-boot.bin.usb.tpl` from the SDK's vendor u-boot (2015.01) for boards
`axg_hubv3_v1` / `axg_hubv3l_v1`. That u-boot implements the Amlogic USB
burning protocol, which mainline u-boot does not; it only runs in RAM during
burning, and the bootloader written to eMMC is the mainline `<u-boot.bin>`.

Its `checkhw()` name must equal the `amlogic-dt-id` in `dts/`, and it must have
exactly three `_` fields because `dtbtools/dtbTool.c` only parses
`soc_platform_variant`.

To regenerate, build the board's u-boot in the SDK (see the SDK
`README_HUBV3.MD` for the docker command), then copy:

```
make -C output/axg_hubv3_a64_k54_release  uboot-dirclean uboot
make -C output/axg_hubv3l_a64_k54_release uboot-dirclean uboot

cp output/axg_hubv3_a64_k54_release/images/u-boot.bin.usb.bl2  burn/loaders/hubv3/DDR.USB
cp output/axg_hubv3_a64_k54_release/images/u-boot.bin.usb.tpl  burn/loaders/hubv3/UBOOT.USB
cp output/axg_hubv3l_a64_k54_release/images/u-boot.bin.usb.bl2 burn/loaders/hubv3l/DDR.USB
cp output/axg_hubv3l_a64_k54_release/images/u-boot.bin.usb.tpl burn/loaders/hubv3l/UBOOT.USB
```

Check `strings UBOOT.USB | grep axg_hubv3` shows the expected dt-id.

## Credits

See [CREDITS.md](CREDITS.md).
