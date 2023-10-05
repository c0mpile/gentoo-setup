#!/usr/bin/env bash

# unset variables
unset disk,subvol_options,current_stage3,work_dir

# set current path
work_dir=$(pwd)

# target installation drive - if you're using a sata drive instead of nvme you must change all instances of ${disk}p1 and ${disk}p2 in the script to ${disk}1 and {disk}2
disk="/dev/nvme0n1"

# wipe target drive
echo "--- Wiping target drive --- "
wipefs -af $disk
sgdisk --zap-all --clear $disk
partprobe $disk

# create partitions
echo "--- Creating partitions --- "
sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:esp $disk
sgdisk -n 0:0:0 -t 0:8309 -c 0:luks $disk
partprobe $disk

# encrypt and unlock root device
echo "--- Setting up encryption --- "
cryptsetup --type luks1 -v -y luksFormat ${disk}p2
cryptsetup luksOpen ${disk}p2 crypt

# create efi boot partition and btrfs root
echo "--- Formatting partitions --- " 
mkfs.vfat -F32 -n ESP ${disk}p1
mkfs.btrfs -L gentoo /dev/mapper/crypt

# create chroot directory and mount encrypted btrfs partition
echo "--- Mounting encrypted partition --- "
mkdir /mnt/gentoo
mount /dev/mapper/crypt /mnt/gentoo

# create btrfs subvolumes
echo "--- Creating BTRFS subvolumes --- "
btrfs su cr /mnt/gentoo/@
btrfs su cr /mnt/gentoo/@home
btrfs su cr /mnt/gentoo/@opt
btrfs su cr /mnt/gentoo/@srv
btrfs su cr /mnt/gentoo/@snapshots
btrfs su cr /mnt/gentoo/@log
btrfs su cr /mnt/gentoo/@tmp
btrfs su cr /mnt/gentoo/@cache
btrfs su cr /mnt/gentoo/@images

# unmount chroot directory
echo "--- Unmounting /mnt/gentoo --- "
umount /mnt/gentoo

# set mount options for subvolumes
echo "--- Setting subvolume mount options --- "
subvol_options="rw,noatime,compress=zstd,space_cache=v2"

# mount root filesystem
echo "--- Mounting root filesystem --- "
mount -o ${subvol_options},subvol=@ /dev/mapper/crypt /mnt/gentoo/

# create mountpoints for subvolumes
echo "--- Creating mountpoints --- "
mkdir -p /mnt/gentoo/{home,opt,srv,.snapshots,var/log,var/tmp,var/cache,var/lib/libvirt/images,boot/efi}

# mount remaining subvolumes
echo "--- Mounting remaining subvolumes --- "
mount -o ${subvol_options},subvol=@home /dev/mapper/crypt /mnt/gentoo/home
mount -o ${subvol_options},subvol=@opt /dev/mapper/crypt /mnt/gentoo/opt
mount -o ${subvol_options},subvol=@srv /dev/mapper/crypt /mnt/gentoo/srv
mount -o ${subvol_options},subvol=@snapshots /dev/mapper/crypt /mnt/gentoo/.snapshots
mount -o ${subvol_options},subvol=@log /dev/mapper/crypt /mnt/gentoo/var/log
mount -o ${subvol_options},subvol=@tmp /dev/mapper/crypt /mnt/gentoo/var/tmp
mount -o ${subvol_options},subvol=@cache /dev/mapper/crypt /mnt/gentoo/var/cache
mount -o ${subvol_options},subvol=@images /dev/mapper/crypt /mnt/gentoo/var/lib/libvirt/images

# mount efi boot partiton
echo "--- Mounting EFI partition --- "
mount ${disk}p1 /mnt/gentoo/boot/efi

# copy chroot script to installation directory
cp ${work_dir}/chroot.sh /mnt/gentoo
chmod +x /mnt/gentoo/chroot.sh

cd /mnt/gentoo

# download latest stage3 tarball with systemd and merged usr
echo "--- Downloading latest stage3 tarball with systemd and merged usr --- "
current_stage3="$(grep -Po "^[0-9]{8}T[0-9]{6}Z/[^[:space:]]+" < <(curl --fail --show-error --location "https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-systemd-mergedusr.txt"))"
curl --fail --show-error --location --remote-name-all "https://distfiles.gentoo.org/releases/amd64/autobuilds/${current_stage3}"

# extract stage3 tarball
echo "--- Extracting stage3 tarball --- "
tar -xpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

# remove stage3 tarball
echo "--- Removing stage3 tarball --- "
rm -rf /mnt/gentoo/stage3-*.tar.xz

# get UUIDs of target partitions
echo "--- Finding UUIDs of target partitions --- "
export p2_uuid=$(blkid -s UUID -o value ${disk}p2)
export mapped_uuid=$(blkid -s UUID -o value /dev/mapper/crypt)

# configure dracut with correct UUIDs for initramfs generation
echo "--- Writing dracut config --- "
echo "add_dracutmodules+=\" crypt dm rootfs-block \"" > /mnt/gentoo/etc/dracut.conf
echo "kernel_cmdline+=\" root=UUID=${mapped_uuid} rd.luks.uuid=${p2_uuid} \"" >> /mnt/gentoo/etc/dracut.conf

# copy dns settings
echo "--- Copying DNS settings --- "
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

# mount remaining necessary filesystems
echo "--- Mounting necessary filesystems for chroot --- "
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

# create fstab
echo "--- Generating fstab --- "
genfstab -U -p /mnt/gentoo >> /mnt/gentoo/etc/fstab

# enter chroot
echo "Entering chroot..."
chroot /mnt/gentoo /chroot.sh
