#!/usr/bin/env bash

unset installed_gpu,locale_num,profile_num

# updating environment
env-update
source /etc/profile
PS1="(chroot) ${PS1}"

# sync portage snapshot
echo "--- Syncing portage snapshot ---"
(emerge-webrsync &)
wait

# setting locale
echo "--- Setting locale ---"
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
(locale-gen &)
wait
echo "LANG=\"en_US.UTF-8\"
LC_COLLATE=\"C.UTF-8\"" > /etc/env.d/02locale
localectl set-locale LANG=en_US.UTF-8
source /etc/profile
env-update
PS1="(chroot) ${PS1}"

# set keyboard layout
echo "--- Setting keyboard layout ---"
read -p "Enter desired keyboard layout: " kb_map
localectl set-keymap ${kb_map}
localectl set-x11-keymap ${kb_map}

# list and select profile
eselect profile list
read -p "Enter the number of your desired profile: " profile_num
eselect profile set ${profile_num}

# emerging necessary packages for setup
echo "--- Emerging necessary packages for setup ---"
emerge --ask --quiet-build --autounmask-write app-portage/cpuid2cpuflags sys-apps/lshw app-eselect/eselect-repository dev-vcs/git
dispatch-conf
emerge --ask --quiet-build app-portage/cpuid2cpuflags sys-apps/lshw app-eselect/eselect-repository dev-vcs/git

# detecting gpu vendor
echo "--- Detecting GPU --- "
if [[ $(lshw -C display | grep vendor) =~ Nvidia ]]; then
	export installed_gpu="nvidia"
elif [[ $(lshw -C display | grep vendor) =~ AMD ]]; then
	export installed_gpu="amdgpu radeonsi"
elif [[ $(lshw -C display | grep vendor) =~ Intel ]]; then
	export installed_gpu="intel"
fi

# writing make.conf
echo "--- Writing make.conf --- "
echo "COMMON_FLAGS=\"-march=native -O2 -pipe\"
CFLAGS=\"\${COMMON_FLAGS}\"
CXXFLAGS=\"\${COMMON_FLAGS}\"
FCFLAGS=\"\${COMMON_FLAGS}\"
FFLAGS=\"\${COMMON_FLAGS}\"
$(cpuid2cpuflags | sed 's/:\s/="/; s/$/"/')
MAKEOPTS=\"-j$(nproc) -l$(nproc)\"
EMERGE_DEFAULT_OPTS=\"--jobs $(nproc) --load-average $(nproc) --keep-going --verbose --quiet-build --with-bdeps=y --complete-graph=y --deep --ask\"

USE=\"systemd X wayland xwayland screencast vulkan opengl btrfs gtk qt5 qt6 policykit udisks udev dbus networkmanager usb bzip2 zstd v4l x264 x265 ffmpeg vaapi vdpau lv2 v4l gstreamer pulseaudio alsa pipewire sndfile taglib cups unicode offensive -dvd -cdr -ios -ipod -clamav -gnome -kde -debug -webengine -qtwebengine -selinux\"

ACCEPT_KEYWORDS=\"~amd64\"
ACCEPT_LICENSE=\"*\"

# NOTE: This stage was built with the bindist Use flag enabled
DISTDIR=\"/var/cache/distfiles\"
PKGDIR=\"/var/cache/binpkgs\"

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C.utf8

VIDEO_CARDS=\"${installed_gpu}\"
INPUT_DEVICES=\"libinput evdev joystick\"
GRUB_PLATFORMS=\"efi-64\"

GENTOO_MIRRORS=\"https://mirrors.mit.edu/gentoo-distfiles https://mirrors.rit.edu/gentoo https://mirror.leaseweb.com/gentoo https://gentoo.osuosl.org https://mirror.clarkson.edu/gentoo\"" > /etc/portage/make.conf

# set package.use
echo "--- Writing package.use --- "
rm -rf /etc/portage/package.use
cp /root/gentoo-setup/portage/package.use /etc/portage

# emerging profile
echo "--- Emerging @world...this could take awhile ---"
USE="-gpm" emerge --oneshot --ask ncurses
emerge --oneshot --ask gpm
emerge --oneshot --ask sys-apps/portage
emerge --oneshot --ask ncurses
emerge -vuDN @world

# copy custom kernel config snippets
echo "--- Copying custom kernel config snippets ---"
mkdir -p /etc/kernel/config.d/
cp /root/gentoo-setup/kernel/* /etc/kernel/config.d/

# emerge kernel
emerge --ask sys-kernel/linux-firmware
emerge --ask sys-kernel/installkernel-gentoo
emerge --ask sys-kernel/gentoo-kernel
