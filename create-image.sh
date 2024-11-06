#!/bin/env bash

filename="$(basename $0)"
if [ "$EUID" -ne 0 ]; then
  exec sudo bash "$filename" $@
fi

scriptloc="$(dirname $0)"
cd $scriptloc
mkdir -p work
cd work

IMAGE_TARBALL_URL="http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
IMAGE_TARBALL_NAME="ArchLinuxARM-rpi-aarch64-latest.tar.gz"

IMG_FILE="archlinuxarm-rpi.img"

function section() {
  local len=${#1}
  local line=$(printf "%0.s-" $(seq 1 $len))
  
  if [ $# -eq 1 ]; then # hack so the first header doesn't have an extra newline
    echo
  fi

  echo "$line"
  echo "$1"
  echo "$line"
}

function cleanup() {
  echo "Cleaning up..."
  run umount boot root
  run rm -rf boot root
  run losetup -d "$LOOP_DEVICE"
  cd - > /dev/null
}

function check() {
  if [ $? -ne 0 ]; then
    echo "Command failed. Aborting..."
    cleanup
    exit $?
  fi
}

function run() {
  echo
  echo "executing: $@"
  eval "$@"
  check
}

section "Downloading image tarball" "this is the hack mentioned above"
if [ ! -f "$IMAGE_TARBALL_NAME" ]; then
  run wget "$IMAGE_TARBALL_URL"
  run chmod 644 "$IMAGE_TARBALL_NAME"
else
  echo "Image tarball already downloaded"
fi

section "Calculating image size"
size=$(tar -tvf <(zcat $IMAGE_TARBALL_NAME) | awk '{total += $3} END {print total}')
# check if one of the arguments starts with safe-buffer-space=
# if so, use that value as the buffer size
# otherwise, assign a default value of 50% buffer
for arg in "$@"; do
  if [[ $arg == safe-buffer-space=* ]]; then
    safe_buffer_space=${arg#safe-buffer-space=}
    echo "Using provided safe buffer space of $safe_buffer_space%"
    break
  fi
done
if [ -z "$safe_buffer_space" ]; then
  safe_buffer_space=50
  echo "Using default safe buffer space of 50%"
fi
buffer_size=$((size * (100 + safe_buffer_space) / 100))
img_size_mb=$((buffer_size / 1024 / 1024))

section "Creating .img file"
if [ -f "$IMG_FILE" ]; then
  run rm -f "$IMG_FILE"
fi

run dd if=/dev/zero of="$IMG_FILE" bs=1M count="$img_size_mb" status=progress
run chmod 644 "$IMG_FILE"

section "Attaching loop device"
echo "losetup -fP --show $IMG_FILE"
LOOP_DEVICE=$(losetup -fP --show "$IMG_FILE")
check

if [ -z "$LOOP_DEVICE" ]; then
    echo "Failed to set up loop device."
    cleanup
    exit 1
fi

section "Creating partitions"
{
    
    echo o        # Wipe partition table

    echo n        # New partition
    echo p        # Primary
    echo 1        # Partition number 1
    echo          # Default first sector
    echo +400M    # Size of the partition

    echo t        # Change partition type
    echo c        # W95 FAT32 (LBA)

    echo n        # New partition
    echo p        # Primary
    echo 2        # Partition number 2
    echo          # Default first sector
    echo          # Default last sector

    echo w        # Write changes
} | fdisk "$LOOP_DEVICE"

section "Formatting partitions"
run mkfs.vfat "${LOOP_DEVICE}p1"
run mkfs.ext4 "${LOOP_DEVICE}p2"

section "Creating directories"
run mkdir -p boot root

section "Mounting partitions"
run mount "${LOOP_DEVICE}p1" boot
run mount "${LOOP_DEVICE}p2" root

section "Extracting image"
run bsdtar -xpf "$IMAGE_TARBALL_NAME" -C root
run sync

section "Moving boot files to boot partition"
run mv root/boot/* boot

section "Fixing fstab"
run sed -i 's/mmcblk0/mmcblk1/g' root/etc/fstab

section "Cleaning up"
run umount boot root
run losetup -d "$LOOP_DEVICE"
run rm -rf boot root
cd - > /dev/null
run mv $scriptloc/work/$IMG_FILE .

section "Done setting up image"

echo
echo "To write the image to an SD card, run:"
echo "sudo dd if=$IMG_FILE of=/dev/sdX bs=4M status=progress"
echo "OR"
echo "Use Raspberry Pi Imager to write the image to an SD card"

