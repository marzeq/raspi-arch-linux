#!/bin/env bash

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

  echo
  echo "$line"
  echo "$1"
  echo "$line"
}

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

section "Downloading image tarball"
if [ ! -f "$IMAGE_TARBALL_NAME" ]; then
  wget "$IMAGE_TARBALL_URL"
  chmod 644 "$IMAGE_TARBALL_NAME"
else
  echo "Image tarball already downloaded"
fi

section "Creating directories"
mkdir -p boot root

section "Extracting image"
bsdtar -xpf "$IMAGE_TARBALL_NAME" -C root
sync

size=$(du -sb root | awk '{print $1}')
buffer_size=$((size * 110 / 100))  # 10% buffer
img_size_mb=$((buffer_size / 1024 / 1024))

section "Copying boot files"
mkdir -p boot root
mv root/boot/* boot

section "Fixing fstab"
sed -i 's/mmcblk0/mmcblk1/g' root/etc/fstab

section "Creating .img file"
if [ -f "$IMG_FILE" ]; then
  rm -f "$IMG_FILE"
fi

dd if=/dev/zero of="$IMG_FILE" bs=1M count="$img_size_mb" status=progress
chmod 644 "$IMG_FILE"

section "Attaching loop device"
LOOP_DEVICE=$(losetup -fP --show "$IMG_FILE")

if [ -z "$LOOP_DEVICE" ]; then
    echo "Failed to set up loop device."
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
mkfs.vfat "${LOOP_DEVICE}p1"
mkfs.ext4 "${LOOP_DEVICE}p2"

section "Mounting partitions"
mount "${LOOP_DEVICE}p1" boot
mount "${LOOP_DEVICE}p2" root

section "Cleaning up"
umount boot root
rm -rf boot root
losetup -d "$LOOP_DEVICE"
cd - > /dev/null
mv $scriptloc/work/$IMG_FILE .

section "Done setting up image"

echo
echo "To write the image to an SD card, run:"
echo "sudo dd if=$IMG_FILE of=/dev/sdX bs=4M status=progress"
echo "OR"
echo "Use Raspberry Pi Imager to write the image to an SD card"

