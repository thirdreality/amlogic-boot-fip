# Credits

- `fip/` is a trimmed fork of
  [LibreELEC/amlogic-boot-fip](https://github.com/LibreELEC/amlogic-boot-fip);
  `axg.inc`, `build-fip.sh`, `acs_tool.py`, `blx_fix.sh` and the per-board
  `Makefile` come from there.
- `burn/` derives from
  [jethome-tools](https://github.com/jethome-iot/jethome-tools) by JetHome
  (Vyacheslav Bocharov). JetHub boards and JetHome-built loaders have been
  removed.
- `burn/dtbtools/dtbTool.c` is Copyright (c) 2012, Code Aurora Forum, under the
  BSD license in the file header.
- `burn/dts/include/meson-axg.dtsi` (Amlogic, GPL-2.0+ OR MIT) and
  `burn/dts/dt-bindings/` come from the Linux kernel tree.
- Firmware blobs, `aml_encrypt_axg`, `aml_image_v2_packer_new` and the USB
  loaders are from the Amlogic OpenLinux SDK.
