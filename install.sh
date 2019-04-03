#!/bin/bash

### 1) Check internet connection
# still to do

### 2) Disk partitioning
# partitioning

# formatting
mkfs.ext2 -L BOOT /dev/vda1
mkfs.fat -F32 -n EFI /dev/vda2
mkfs.ext4 -L ROOT /dev/vda3
mkswap -L SWAP /dev/vda4

### 3) Set date
# still to do

### 4) Mount root
mkdir -p /mnt/gentoo
mount /dev/vda3 /mnt/gentoo
swapon /dev/vda4
cd /mnt/gentoo
wget http://distfiles.gentoo.org/releases/amd64/autobuilds/20190331T214502Z/stage3-amd64-20190331T214502Z.tar.xz
tar xpvf stage3-amd64-20190331T214502Z.tar.xz --xattrs-include='*.*' --numeric-owner

### 5) make.conf
echo 'CFLAGS="-march=native -O2 -pipe"' > /mnt/gentoo/etc/portage/make.conf
echo 'CXXFLAGS="${CFLAGS}"' >> /mnt/gentoo/etc/portage/make.conf
echo 'CHOST="x86_64-pc-linux-gnu"' >> /mnt/gentoo/etc/portage/make.conf
echo 'MAKEOPTS="-j6"' >> /mnt/gentoo/etc/portage/make.conf
echo 'CPU_FLAGS_X86="aes avx avx2 f16c fma3 mmx mmxext pclmul popcnt sse sse2 sse3 sse4_1 sse4_2 sse4a ssse3"' >> /mnt/gentoo/etc/portage/make.conf
echo 'ACCEPT_KEYWORDS="amd64"' >> /mnt/gentoo/etc/portage/make.conf
echo 'INPUT_DEVICES="libinput"' >> /mnt/gentoo/etc/portage/make.conf
echo 'ACCEPT_LICENSE="-* @FREE"' >> /mnt/gentoo/etc/portage/make.conf

### 6) repos.conf
mkdir -p /mnt/gentoo/etc/portage/repos.conf

echo "[DEFAULT]" > /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "main-repo = gentoo" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo -e "\n" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf 
echo "[gentoo]" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "location = /usr/portage" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-type = rsync" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-uri = rsync://rsync.gentoo.org/gentoo-portage" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "auto-sync = yes" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-rsync-verify-jobs = 1" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-rsync-verify-metamanifest = yes" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-rsync-verify-max-age = 24" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-openpgp-key-path = /usr/share/openpgp-keys/gentoo-release.asc" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-openpgp-key-refresh-retry-count = 40" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-openpgp-key-refresh-retry-overall-timeout = 1200" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-openpgp-key-refresh-retry-delay-exp-base = 2" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-openpgp-key-refresh-retry-delay-max = 60" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf
echo "sync-openpgp-key-refresh-retry-delay-mult = 4" >> /mnt/gentoo/etc/portage/repos.conf/repos.conf

### 7) resolv.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

### 8) Mounts
mkdir -p /mnt/gentoo/boot/efi
mount /dev/vda1 /mnt/gentoo/boot
mount /dev/vda2 /mnt/gentoo/boot/efi
mount -t proc proc /mnt/gentoo/proc
mount -R /sys /mnt/gentoo/sys
mount -R /dev /mnt/gentoo/dev

### 9) Enter chroot
chroot /mnt/gentoo /bin/bash -x <<'EOF'
su -
source /etc/profile && export PS1="(chroot) $PS1"

### 10) Sync Portage
emerge-webrsync
emerge --sync

### 11) Set profile
eselect profile set 12

### 12) Update @world
emerge --update --deep --newuse --autounmask-write @world

### 13) Timezone
echo "Europe/Amsterdam" > /etc/timezone
emerge --config sys-libs/timezone-data

### 14) Locale
echo "en_US.UTF-8" > /etc/locale.gen
locale-gen
eselect locale set en_US.utf-8
env-update && source /etc/profile && export PS1="chroot $PS1"

### 15) Fstab
echo "LABEL=BOOT       /boot                   ext2            rw,relatime     0 2" > /etc/fstab
echo "LABEL=EFI        /boot/efi               vfat            rw,defaults     0 0" >> /etc/fstab 
echo "LABEL=ROOT       /		       ext4	       rw,defaults     0 0" >> /etc/fstab
echo "LABEL=SWAP       none                    swap            defaults        0 0" >> /etc/fstab

### 16) Emerge basic packages
mkdir -p /etc/portage/package.keywords
mkdir -p /etc/portage/package.license
echo ">=net-wireless/wpa_supplicant-2.6-r10 dbus" > /etc/portage/package.use/networkmanager
echo ">=sys-apps/util-linux-2.33-r1 static-libs" > /etc/portage/package.use/genkernel
echo ">=sys-kernel/linux-firmware-20190313 linux-firmware no-source-code" > /etc/portage/package.license/all

emerge sys-kernel/gentoo-sources sys-kernel/genkernel sys-apps/pciutils sys-kernel/linux-firmware app-admin/sysklogd sys-process/cronie sys-apps/mlocate sys-boot/grub net-misc/networkmanager && \

### 17) Kernel
eselect kernel set 1
MAKEOPTS="-j6" genkernel all

### 18) Hostname
echo "gentoo-vm" > /etc/hostname

### 19) Add inits
rc-update add NetworkManager default
rc-update add cronie default
rc-update add sysklogd default
rc-update add sshd default

### 20) Grub
grub-install --efi-directory=/boot/efi --target=x86_64-efi
grub-mkconfig -o /boot/grub/grub.cfg

### 21) Remove stage3
rm /stage3-amd64-20190331T214502Z.tar.xz 

### 22) Useraccounts and passwords
echo -e "difficultpassword\ndifficultpassword" | passwd root
useradd -m -G users,wheel,audio,portage,usb,video,input,plugdev -s /bin/bash user 
echo -e "12345\n12345" | passwd user

echo "!!!!!!!!!!!!IMPORTANT: YOUR PASSWORDS! TAKE NOTICE!!!!!!!!!!!!!!!"
echo "-----------------------------------------------------------------"
echo "root --> 'difficultpassword'"
echo "user --> '12345'"
echo "-----------------------------------------------------------------"

### 23) Reboot
echo "Time to Reboot!"
EOF
