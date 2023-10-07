#!/usr/bin/env bash

unset installed_gpu,locale_num,profile_num,kb_map

# updating environment
env-update
source /etc/profile
PS1="(chroot) ${PS1}"

# sync portage snapshot
echo "--- Syncing portage snapshot ---"
emerge-webrsync &
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
LDFLAGS=\"-Wl,-O2 -Wl,--as-needed\"
$(cpuid2cpuflags | sed 's/:\s/="/; s/$/"/')
RUST_FLAGS=\"-C debuginfo=0 -C codegen-units=1 -C target-cpu=native -C opt-level=2\"
MAKEOPTS=\"-j$(nproc) -l$(nproc)\"
EMERGE_DEFAULT_OPTS=\"--jobs $(nproc) --load-average $(nproc) --keep-going --verbose --quiet-build --with-bdeps=y --complete-graph=y --deep --ask\"

USE=\"minimal X wayland xwayland screencast systemd btrfs pipewire pulseaudio alsa sndfile taglib gstreamer opengl x264 x265 v4l vdpau vaapi lv2 vulkan gtk qt5 qt6 udisks udev dbus policykit networkmanager ipv6 nftables native-symlinks lto pgo jit xs orc threads asm openmp zstd lz4 ffmpeg icu av1 harfbuzz jpeg libevent librnp libvpx png webp ssl zlib cups usb offensive -dvd -cdr -ios -ipod -clamav -gnome -kde -selinux -ufw -iptables -qtwebengine -webengine\"

ACCEPT_KEYWORDS=\"~amd64\"
ACCEPT_LICENSE=\"*\"

DISTDIR=\"/var/cache/distfiles\"
PKGDIR=\"/var/cache/binpkgs\"
LC_MESSAGES=C.utf8

VIDEO_CARDS=\"${installed_gpu}\"
INPUT_DEVICES=\"libinput evdev joystick\"
GRUB_PLATFORMS=\"efi-64\"

GENTOO_MIRRORS=\"https://mirrors.mit.edu/gentoo-distfiles https://mirrors.rit.edu/gentoo https://mirror.leaseweb.com/gentoo https://gentoo.osuosl.org https://mirror.clarkson.edu/gentoo\"
FEATURES=\"candy fixlafiles parallel-install parallel-fetch\"
FETCHCOMMANDWRAPPER_OPTIONS=\"--max-concurrent-downloads=50 --max-connection-per-server=50 --min-split-size=10M --max-file-not-found=1 --max-tries=1\"" > /etc/portage/make.conf

# set package.use
echo "--- Writing package.use --- "
mkdir /etc/portage/profile
rm -rf /etc/portage/{package.use,package.accept_keywords,profile/package.unmask,use.mask}
cp -R /root/gentoo-setup/portage/* /etc/portage

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
