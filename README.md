# amlogic-boot-fip (ThirdReality hubv3 branch)

FIP blobs used to sign mainline u-boot (BL33) for ThirdReality Amlogic A113X
(axg) boards in Armbian. This branch contains ThirdReality boards only; for
other boards use the upstream `master` branch
(https://github.com/LibreELEC/amlogic-boot-fip).

## Boards

| Directory              | Board                       | DDR                                      |
|------------------------|-----------------------------|------------------------------------------|
| `thirdreality-hubv3`   | HubV3 (MB0.3)               | 1x DDR4, 16bit, 1 rank, 2GB @ 1200MHz    |
| `thirdreality-hubv3l`  | HubV3L (LinuxBox-Lite MB0.5)| 2x DDR3, 16bit, 2 ranks, 1GB @ 912MHz    |

The two directories differ only in `acs.bin` (DDR parameters). Do not swap
them: the bl2 DDR auto-detect does not cover the HubV3L 2-rank layout.

## Origin of the blobs

Taken from the `fip/_tmp/` directory of an Amlogic OpenLinux buildroot SDK
2025r1 build, configs `axg_hubv3_a64_k54_release` / `axg_hubv3l_a64_k54_release`
(u-boot boards `axg_hubv3_v1` / `axg_hubv3l_v1`):

| File        | Source                                   | Version                         |
|-------------|------------------------------------------|---------------------------------|
| `bl2.bin`   | SDK `bl2/bin/axg`                        | g226aefb1, 2025-08-26           |
| `bl30.bin`  | SDK `bl30/bin/axg`                       | axg_v1.1.3545-2c4752ec29        |
| `bl31.img`  | SDK `bl31/bl31_1.3/bin/axg`              | v1.3.2(release):9593a7478       |
| `acs.bin`   | built from `axg_hubv3*_v1.h` DDR config  | per board                       |
| `bl301.bin` | built from SDK board `scp_task`          | same for both boards            |
| `bl21.bin`  | built from SDK board firmware            | same for both boards            |

`aml_encrypt_axg`, `acs_tool.py`, `blx_fix.sh` and `Makefile` are unchanged
from upstream (`aml_encrypt_axg` is identical to the SDK copy).

No BL32 (OP-TEE) is packaged, same as the SDK output for these boards.
No encrypted / efuse artifacts are included; these blobs are for
non-secure-boot chips only.

## Usage

```
./build-fip.sh thirdreality-hubv3 /path/to/u-boot/u-boot.bin my-output-dir
```

Output: `u-boot.bin`, `u-boot.bin.sd.bin`, `u-boot.bin.usb.bl2`,
`u-boot.bin.usb.tpl`.

System requirements: x86-64 Linux (or qemu-x86_64), python3, sh, make,
readlink, mktemp, cat, dd.
