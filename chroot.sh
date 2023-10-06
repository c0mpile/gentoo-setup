#!/usr/bin/env bash

unset installed_gpu

# updating environment
env-update
source /etc/profile
PS1="(chroot) ${PS1}"

# sync portage snapshot
echo "--- Syncing portage snapshot ---"
emerge --sync --quiet

# setting locale
echo "--- Setting locale ---"
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
source /etc/profile
env-update

# emerging necessary packages for setup
echo "--- Emerging necessary packages for setup ---"
emerge --quiet-build app-portage/cpuid2cpuflags sys-apps/lshw app-eselect/eselect-repository dev-vcs/git

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

USE=\"dist-kernel systemd btrfs udev policykit udisks dbus inotify libnotify networkmanager bzip2 zstd X screencast wayland xwayland vulkan opengl gtk qt5 qt6 x264 x265 gstreamer pulseaudio alsa pipewire pipewire-jack pipewire-alsa dri vaapi vdpau cups v4l ssl lv2 unicode offensive amd64 -dvd -cdr -ios -ipod -clamav -gnome -kde -debug\"

ACCEPT_KEYWORDS=\"~amd64\"
ACCEPT_LICENSE=\"*\"

# NOTE: This stage was built with the bindist Use flag enabled
DISTDIR=\"/var/cache/distfiles\"
PKGDIR=\"/var/cache/binpkgs\"

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C.utf8

VIDEO_CARDS=\"${installed_gpu}\"
INPUT_DEVICES=\"libinput\"
GRUB_PLATFORMS=\"efi-64\"

GENTOO_MIRRORS=\"https://mirrors.mit.edu/gentoo-distfiles https://mirrors.rit.edu/gentoo https://mirror.leaseweb.com/gentoo https://gentoo.osuosl.org https://mirror.clarkson.edu/gentoo\"" > /etc/portage/make.conf

# set package.use
echo "--- Writing package.use --- "
rm -rf /etc/portage/package.use
echo "www-client/ungoogled-chromium-bin widevine
media-video/vlc -vaapi
media-libs/libsndfile minimal
sys-apps/systemd cryptsetup
sys-boot/grub device-mapper
sys-kernel/installkernel-gentoo grub
sys-apps/dbus abi_x86_32

# STEAM #
x11-libs/libX11  abi_x86_32
x11-libs/libXau  abi_x86_32
x11-libs/libxcb  abi_x86_32
x11-libs/libXdmcp  abi_x86_32
virtual/opengl  abi_x86_32
media-libs/mesa  abi_x86_32
dev-libs/expat  abi_x86_32
media-libs/libglvnd  abi_x86_32
sys-libs/zlib  abi_x86_32
x11-libs/libdrm  abi_x86_32
x11-libs/libxshmfence  abi_x86_32
x11-libs/libXext  abi_x86_32
x11-libs/libXxf86vm  abi_x86_32
x11-libs/libXfixes  abi_x86_32
app-arch/zstd  abi_x86_32
sys-devel/llvm  abi_x86_32
x11-libs/libXrandr  abi_x86_32
x11-libs/libXrender  abi_x86_32
dev-libs/libffi  abi_x86_32
sys-libs/ncurses  abi_x86_32
dev-libs/libxml2  abi_x86_32
dev-libs/icu  abi_x86_32
sys-libs/gpm  abi_x86_32
virtual/libelf  abi_x86_32
dev-libs/elfutils  abi_x86_32
app-arch/bzip2  abi_x86_32
net-misc/networkmanager  abi_x86_32
dev-libs/nspr  abi_x86_32
dev-libs/nss  abi_x86_32
net-libs/libndp  abi_x86_32
x11-libs/extest abi_x86_32
dev-libs/libevdev abi_x86_32
dev-libs/wayland abi_x86_32
virtual/rust abi_x86_32
dev-lang/rust-bin abi_x86_32" > /etc/portage/package.use
