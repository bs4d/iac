#!/bin/sh
set -ex

# set the timezone
ln --symbolic --force /usr/share/zoneinfo/Europe/Warsaw /etc/localtime

# sync with hardware clock
hwclock --systohc

# generate locales
sed --in-place --expression='s/^#pl_PL/pl_PL/' /etc/locale.gen
sed --in-place --expression='s/^#en_US/en_US/' /etc/locale.gen
locale-gen

# enable network time sync
timedatectl set-ntp true

# enable fstrim
systemctl enable fstrim.timer

# set the locale
echo 'LANG=pl_PL.UTF-8' > /etc/locale.conf

# set the console options
echo 'KEYMAP=pl
FONT=latarcyrheb-sun32' > /etc/vconsole.conf

# set the hostname
echo "$HOSTNAME" > /etc/hostname

# configure /etc/hosts
echo "127.0.0.1 localhost $HOSTNAME" >> /etc/hosts

# enable network daemons
systemctl enable dhcpcd NetworkManager

# set  the root password
passwd -s << EOF
$ROOT_PASSWORD
EOF

# add disk decryption to initramfs and regenerate it
sed --in-place --expression='/^[^#]/s/block filesystems/block encrypt lvm2 filesystems/' /etc/mkinitcpio.conf
mkinitcpio --allpresets

# get the root partition's uuid
uuid=$(blkid | grep "${DISK}2" | cut --delimiter=' ' --fields=2 | sed 's/"//g')

# set boot timeout to 0
sed --in-place --expression='/^GRUB_TIMEOUT/s/5/0/' /etc/default/grub

# set boot options
sed --in-place --expression="/^GRUB_CMDLINE_LINUX_DEFAULT/s/\"\$/ cryptdevice=${uuid}:arch root=\/dev\/mapper\/arch-root lang=pl locale=pl_PL.UTF-8\"/" /etc/default/grub

# install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# generate grub config
grub-mkconfig --output=/boot/grub/grub.cfg

# create user
useradd --create-home "$USER_NAME"

# set the user password
passwd "$USER_NAME" << EOF
$USER_PASSWORD
$USER_PASSWORD
EOF

# set up doas permissions for the user
echo "permit nopass $USER_NAME" > /etc/doas.conf

# create a git directory for the user
mkdir "/home/$USER_NAME/git"

# move the iac repository to it
mv /root/iac "/home/$USER_NAME/git/iac"

# set proper ownership
chown --recursive "$USER_NAME:$USER_NAME" "/home/$USER_NAME/git"

# create getty tty1 service directory
mkdir --parents /etc/systemd/system/getty@tty1.service.d

# enable tty autologin
> /etc/systemd/system/getty@tty1.service.d/autologin.conf cat << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin $USER_NAME %I \$TERM
EOF
