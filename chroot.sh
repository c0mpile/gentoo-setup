#!/usr/bin/env bash

unset installed_gpu,proc_count

# updating environment
env-update
source /etc/profile
PS1="(chroot) ${PS1}"

# detecting processor cores/threads
echo "--- Detecting CPU --- "
makeopts_proc=$(nproc)

# sync portage snapshot
echo "--- Syncing portage snapshot ---"
emerge-webrsync

# emerging necessary packages for setup
echo "--- Emerging necessary packages for setup ---"
emerge --ask app-portage/cpuid2cpuflags sys-apps/lshw app-eselect/eselect-repository dev-vcs/git

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
echo 'COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
CPU_FLAGS_X86="$(cpuid2cpuflags)"
MAKEOPTS="-j${makeopts_proc} -l${makeopts_proc}"
EMERGE_DEFAULT_OPTS="--keep-going --verbose --quiet-build --with-bdeps=y --complete-graph=y --deep --ask"
USE=""

ACCEPT_KEYWORDS="~amd64"
ACCEPT_LICENSE="*"

# NOTE: This stage was built with the bindist Use flag enabled
DISTDIR="/var/cache/distfiles"
PKGDIR="/var/cache/binpkgs"

# This sets the language of build output to English.
# Please keep this setting intact when reporting bugs.
LC_MESSAGES=C.utf8

VIDEO_CARDS="${installed_gpu}"
INPUT_DEVICES="libinput"
GRUB_PLATFORMS="efi-64"

GENTOO_MIRRORS="https://mirrors.mit.edu/gentoo-distfiles https://mirrors.rit.edu/gentoo https://mirror.leaseweb.com/gentoo https://gentoo.osuosl.org https://mirror.clarkson.edu/gentoo"' > /etc/portage/make.conf

# set package.use
echo "--- Writing package.use --- "
rm -rf /etc/portage/package.use
echo 'www-client/ungoogled-chromium-bin widevine
media-video/vlc -vaapi
media-libs/libsndfile minimal
sys-apps/systemd cryptsetup
sys-boot/grub device-mapper
sys-kernel/installkernel-gentoo grub
sys-apps/dbus abi_x86_32
sys-apps/bubblewrap -suid

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
dev-lang/rust-bin abi_x86_32' > /etc/portage/package.use
