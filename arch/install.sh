#!/bin/sh
set -ex

# save repository path to a variable
repo_path="$(dirname $(realpath $0) | rev | cut --fields 2- --delimiter / | rev)"

# load the config file
source "$repo_path/arch/config.sh"

# restore the config file back to a template
(cd "$repo_path" && su "$(stat --format '%U' .)" --command 'git restore arch/config.sh')

# wipe the disk
wipefs --all "$DISK"

# create partitions:
# - EFI, 550MB
# - LVM, rest of the disk
fdisk "$DISK" << EOF
g
n
1

+550M
t
1
n
2


t
2
44
w
EOF

# for nvme append 'p' before the partition number
echo "$DISK" | grep --null nvme && DISK="${DISK}p"

# format the EFI partition
mkfs.vfat "${DISK}1"

# load the dm-crypt module
modprobe dm-crypt

# encrypt the LVM partition with LUKS
cryptsetup luksFormat "${DISK}2" <<EOF
$DISK_ENCRYPTION_PASSWORD
YES
EOF

# open it
cryptsetup luksOpen "${DISK}2" lvm << EOF
$DISK_ENCRYPTION_PASSWORD
EOF

# set up LVM with 100% of PV as root
pvcreate /dev/mapper/lvm
vgcreate arch /dev/mapper/lvm
lvcreate --extents 100%FREE arch --name root

# format the root filesystem
mkfs.ext4 /dev/mapper/arch-root

# mount it
mount /dev/mapper/arch-root /mnt

# wipe lost+found
rm --recursive --force /mnt/lost+found

# mount the EFI partition
mount --mkdir "${DISK}1" /mnt/boot

# install basic packages on the target system
pacstrap -K /mnt base linux linux-firmware lvm2 networkmanager dhcpcd doas grub efibootmgr intel-ucode man-db man-pages texinfo ansible

# generate the fstab
genfstab -U /mnt >> /mnt/etc/fstab

# copy the iac repository to target system
cp --recursive "$repo_path" /mnt/root/iac

# run the provisioning script
arch-chroot /mnt /bin/bash < "$repo_path/arch/setup.sh"
