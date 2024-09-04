#!/bin/bash

# Exit on error
set -e

# Disk to be partitioned
DISK="/dev/nvme0n1"

# Warning message and confirmation
echo "WARNING: This script will wipe all data on $DISK."
read -p "Type 'yes' to continue: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Operation cancelled."
    exit 1
fi

# Wipe the disk by deleting all existing partitions
echo "Wiping the disk..."
sgdisk --zap-all $DISK

# Partition the disk
echo "Partitioning the disk..."
parted $DISK --script mklabel gpt
parted $DISK --script mkpart primary fat32 1MiB 513MiB
parted $DISK --script set 1 esp on
parted $DISK --script mkpart primary 513MiB 400513MiB      # Root LVM partition
parted $DISK --script mkpart primary 400513MiB 100%        # Reserved partition for Windows

# Format the EFI partition
echo "Formatting the EFI partition..."
mkfs.fat -F32 ${DISK}p1   # Format /boot partition as FAT32

# Ensure partition type is set for LVM (optional, if not done manually)
echo "Setting partition type for LVM..."
parted $DISK --script set 2 lvm on

# Wipe any existing signatures from the partition
echo "Wiping existing signatures from LVM partition..."
wipefs --all ${DISK}p2

# Set up LVM
echo "Setting up LVM..."
pvcreate ${DISK}p2                             # Create a physical volume on the root partition
vgcreate arch_vg ${DISK}p2                     # Create a volume group named arch_vg
lvcreate -L 400G arch_vg -n root               # Create a 400GB logical volume for root

# Format the LVM root partition
echo "Formatting the LVM root partition..."
mkfs.ext4 /dev/arch_vg/root                    # Format the root logical volume as ext4

# Mount the LVM root partition
echo "Mounting the LVM root partition..."
mount /dev/arch_vg/root /mnt

# Mount the EFI partition
echo "Mounting the EFI partition..."
mkdir /mnt/boot
mount ${DISK}p1 /mnt/boot

# Install base system packages (base, linux, linux-firmware) into /mnt
echo "Installing base system..."
pacstrap -K /mnt base linux linux-firmware lvm2

# Generate fstab file for the installed system
echo "Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

# Copy the Chroot_Script.sh to the new environment
echo "Copying Chroot_Script.sh to /mnt..."
cp Chroot_Script.sh /mnt
chmod +x /mnt/Chroot_Script.sh

# Verify the script is copied successfully
if [ ! -f /mnt/Chroot_Script.sh ]; then
    echo "Error: Chroot_Script.sh not found in /mnt"
    exit 1
fi

# Copy the PostInstall.sh to the new environment
echo "Copying PostInstall.sh to /mnt..."
cp PostInstall.sh /mnt
chmod +x /mnt/PostInstall.sh

# Chrooting and executing the script
echo "Chrooting into new env and executing Chroot_Script.sh..."
arch-chroot /mnt /bin/bash -c "./Chroot_Script.sh"

# Inside Chroot: GRUB Installation
echo "Installing and configuring GRUB..."
arch-chroot /mnt /bin/bash <<EOF
pacman -S --noconfirm grub efibootmgr lvm2
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

# Unmount all partitions and clean up
echo "Unmounting all partitions and cleaning up..."
umount -R /mnt

# Prompt to reboot
echo "Installation complete! Please reboot your system."