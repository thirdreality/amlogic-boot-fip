#!/bin/bash

HERE="$(dirname "$(readlink -f "$0")")"
source "$HERE/lib.sh"

usage() {
    echo Usage:
    echo "      $0 <input> <v3|v3a|v3b|v3l> armbian [compress] <uboot>"
    echo
    echo "              input           - input image (.img or .img.xz)"
    echo "              v3|v3a|v3b|v3l  - ThirdReality HubV3 variant"
    echo "              armbian         - partition table type"
    echo "              compress        - 'compress' or 'no' output to zip"
    echo "              uboot           - path to u-boot binary"
    echo
    echo "      Output goes to \$OUTPUT_DIR (default: ./output)."
    exit 1
}

[ $# -lt 3 ] && usage

if [[ "$2" == "v3" || "$2" == "trhubv3" ]]; then
  DTS="meson-axg-thirdreality-trhub-v3.dts"
  CNAME="hubv3"
elif [[ "$2" == "v3l" || "$2" == "trhubv3l" ]]; then
  DTS="meson-axg-thirdreality-trhub-v3l.dts"
  CNAME="hubv3l"
elif [[ "$2" == "v3b" || "$2" == "trhubv3b" ]]; then
  DTS="meson-axg-thirdreality-trhub-v3b.dts"
  CNAME="hubv3"
elif [[ "$2" == "v3a" || "$2" == "trhubv3a" ]]; then
  DTS="meson-axg-thirdreality-trhub-v3a.dts"
  CNAME="hubv3l"
else
  echo "ERROR: unknown controller"
  exit 1
fi

if [[ "$3" == "armbian" ]]; then
  DTI="partition_arm.dtsi"
  CPART="armbian"
else
  echo "ERROR: unknown partition table"
  exit 1
fi

if [[ "$4" == "compress" ]]; then
    COMPRESS=yes
fi

if [[ -e "$5" ]]; then
    UBOOT=$(readlink -f "$5")
else
    echo "Error: u-boot binary did not found"
    exit 1
fi

echo "UBOOT set to ${UBOOT}"

[[ ! -e $1 ]] && echo No file found && exit 1
echo "Selected $CNAME controller with $CPART partition table"

OUTPUT_DIR=$(readlink -f "${OUTPUT_DIR:-output}")
INPUT=$(readlink -f $1)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
DTB="$TMP/${DTS::-4}.dtb"
EXT="${INPUT:${#INPUT}-3:3}"
if [[ ".xz" == "${EXT}" ]]; then
    INPUTE="${INPUT::-3}"
    echo "Found compressed image. Decompress $INPUTE$EXT"
    INPUT="$TMP/$(basename $INPUTE)"
    xzcat "${INPUTE}${EXT}" >"$INPUT"
fi

mkdir -p "$OUTPUT_DIR"
OUTIMG=$(basename $INPUT)
OUEXT="${OUTIMG:${#OUTIMG}-4:4}"
if [[ ".img" == "${OUEXT}" ]]; then
    OUTIMGE="${OUTIMG::-4}"
    OUTIMG="${OUTIMGE}.burn${OUEXT}"
else
    OUTIMG="${OUTIMG}.burn"
fi

cp "$HERE/dts/$DTS" "$TMP/$DTS"
cp "$HERE/dts/$DTI" "$TMP/$DTI"
sed -i "s/partition.dtsi/$DTI/g" "$TMP/$DTS"

cpp -nostdinc -I "$HERE/dts" -I "$HERE/dts/include" -undef -x assembler-with-cpp "$TMP/$DTS" "$TMP/$DTS.preprocess" || exit 1
dtc -I dts -O dtb -p 0x1000 -qqq "$TMP/$DTS.preprocess" -o "$DTB" || exit 1
FDISK=$(/usr/sbin/fdisk -l "$INPUT" | grep -P -A 100 "Device.+Boot.+Start.+End.+Sectors.+Size.+Id.+Type" | sed -- "s/\*//g" | grep "$INPUT"| grep -v Extended)

echo +! Device	! Start	! End	! Sectors	! Size	! Id	! Type	!-
i=1
while read -r line; do
    read -r Device Start End Sectors Size Id Type <<<$line
    Device=$(echo $(basename $Device) | sed --  "s/$(basename $INPUT)//g")
    echo +! $Device	! $Start	! $End	! $Sectors	! $Size	! $Id	! $Type	!-
    extract_partition "$INPUT" $Start $Sectors "$TMP/part-$i.img" || exit 1
    i=$((i + 1))
done <<< "$FDISK"

cp "$HERE/loaders/$CNAME/platform.conf" "$TMP"

cc -o $TMP/dtbTool "$HERE/dtbtools/dtbTool.c" || exit 1
$TMP/dtbTool -o "$TMP/_aml_dtb.PARTITION" "$TMP" || exit 1

cp "$HERE/image.$CPART.cfg" "$TMP/image.cfg"
echo cp "$UBOOT" "$TMP/u-boot.bin"
cp "$UBOOT" "$TMP/u-boot.bin"
cp "$HERE/loaders/$CNAME/DDR.USB" "$TMP"
cp "$HERE/loaders/$CNAME/UBOOT.USB" "$TMP"

"$HERE/tools/aml_image_v2_packer_new" -r "$TMP/image.cfg" "$TMP" "$OUTPUT_DIR/$OUTIMG" || exit 1

if [[ "$COMPRESS" == "yes" ]]; then
    (cd "$OUTPUT_DIR" && zip "$OUTIMG.zip" "$OUTIMG") || exit 1
    rm "$OUTPUT_DIR/$OUTIMG"
fi
