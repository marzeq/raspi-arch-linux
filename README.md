# raspi-arch-linux

This is a repository containing a collection of scripts and guides to create a bootable Arch Linux image for the Raspberry Pi.

## Usage

### Create a bootable Arch Linux image

To create a bootable Arch Linux image for the Raspberry Pi, run the following command:

```bash
./create-image.sh # if you are not root, you will be prompted for your password
```

This will create a bootable Arch Linux image called `archlinuxarm-rpi.img` in your current working directory.

You can provide the `safe-buffer-space=<size-percentage>` argument to the script. It's the amount of space to leave at the end of the image for the root partition (default: 50% of the image size).

From my testing, anything below 50% will not be big enough for the unpacked data to fit in the image due to difference in the calculated unpacked size and the actual unpacked size.
The default value should be just enough to create the smallest possible .img file. If you wish to skip the step of resizing the root partition later on, you can increase this value if you are fine with creating a much larger file.

### Flash the image to an SD card

#### Using `dd`

Plug in your SD card reader and identify its device name. You can use the `lsblk` command to list all block devices:

```bash
lsblk
```

The device will be something like `/dev/sda, /dev/sdb, ...`. For the purpose of this example, we will assume the device name is `/dev/sdX`.

To flash the image to the SD card, run the following command:

```bash
sudo dd if=archlinuxarm-rpi.img of=/dev/sdX bs=4M status=progress
```

#### Using Raspberry Pi Imager

Alternatively, you can use the Raspberry Pi Imager to flash the image to the SD card. Simply select the "Use custom" option and choose the `archlinuxarm-rpi.img` file.

### Boot the Raspberry Pi as a test

Technically, you should be able to boot your Raspberry Pi with the SD card at this point. Boot into the system and check if you can get into the login prompt and/or SSH into the system (default username is `alarm` and password is `alarm`).

However, there is one issue: the root partition will not be resized to fill the entire SD card and you will not be able to perform a system upgrade. To fix this, follow the next section.

### Resize the root partition

To resize the root partition to fill the entire SD card, run the included script:

```bash
./resize-image-on-drive.sh /dev/sdX (partition number - probably 2) # if you are not root, you will be prompted for your password
```

Finally, resize the filesystem to fill the entire root partition:

```bash
sudo e2fsck -f /dev/sdX2
sudo resize2fs /dev/sdX2
```

### Boot the Raspberry Pi & setup

Insert the SD card into the Raspberry Pi, plug it into ethernet (you may use wired tethering from your phone as an alternative) and power it on.

SSH should be enabled by default. You can connect to the R-Pi using the default username `alarm` and password `alarm`, as detailed previously.

Then, change into the `root` user using the following command:

```bash
su # password is "root"
```

Now, you need to initialise and populate the pacman keyring:

```bash
pacman-key --init
pacman-key --populate archlinuxarm
```

Finally, update the system:

```bash
pacman -Syyu
```

At this point, you should have a fully functional Arch Linux system running on your Raspberry Pi. However, you may want to perform some optional steps to further improve the system. These steps are outlined in the next section.

### Optional but good to have

#### Add a new user

To add a new user, run the following commands as root:

```bash
useradd -m <username>
passwd <username>
```

If you wish, you can now remove the default `alarm` user and their home directory:

```bash
userdel -r alarm
rm -rf /home/alarm
```

#### Install and setup sudo

First, install the `sudo` package as the root user:

```bash
pacman -S sudo
```

Next, edit the sudoers file to allow the `sudo` group to execute any command:

```bash
EDITOR=nano visudo
```

Uncomment the following line:

```bash
%sudo ALL=(ALL) ALL
```

Then, create the `sudo` group and add your desired user to it:
```bash
groupadd sudo
usermod -aG sudo <username>
```

From now on, the guide will assume that you have set up the `sudo` group and added your user to it.

#### Change the hostname

To change the hostname, edit the `/etc/hostname` file:

```bash
nano /etc/hostname
```

#### Connect to a Wi-Fi network

Connecting to a Wi-Fi network can be done in many different ways. One way is to use `NetworkManager`:

```bash
sudo pacman -S networkmanager
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
```

Then, use the `nmtui` command to connect to a Wi-Fi network:

```bash
nmtui
```

#### Change the timezone

To change the timezone, create a symbolic link to the desired timezone file:

```bash
sudo ln -sf /usr/share/zoneinfo/<Region>/<City> /etc/localtime # e.g. Europe/Warsaw
```

#### Set the locale

To set the locale, edit the `/etc/locale.gen` file and uncomment the desired locale:

```bash
sudo nano /etc/locale.gen
```

Then, generate the locale:

```bash
sudo locale-gen
```

Finally, set the `LANG` variable in the `/etc/locale.conf` file:

```bash
sudo nano /etc/locale.conf

# add the following line:
LANG=(your locale) # e.g. en_GB.UTF-8
```

#### I/O and Ras-Pi specific hardware

See the Arch Linux Arm wiki [here](https://archlinuxarm.org/wiki/Raspberry_Pi).

## Supported/tested devices

- Raspberry Pi 4 Model B

Feel free to test this on other Raspberry Pi models and let me know if it works!

## Sources

- [Arch Linux ARM](https://archlinuxarm.org/platforms/armv8/broadcom/raspberry-pi-4)
