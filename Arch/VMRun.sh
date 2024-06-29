#!/bin/bash

# Exit on error
set -e

# Disk to be partitioned
DISK="/dev/sda"

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
parted $DISK --script mkpart primary ext4 513MiB 100%

# Format the partitions
echo "Formatting the partitions..."
mkfs.fat -F32 ${DISK}1   # Format /boot partition as FAT32
mkfs.ext4 ${DISK}2       # Format root partition as ext4

echo "Disk partitioning and formatting completed successfully."

# Mount the root partition
echo "Mounting the root partition..."
mount ${DISK}2 /mnt

echo "Root partition mounted successfully."

# Install base system packages (base, linux, linux-firmware) into /mnt
pacstrap -K /mnt base linux linux-firmware

# Generate fstab file for the installed system
echo "Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

# Provide confirmation message
echo "fstab file generated successfully."

# Copy the Chroot_Script.sh to the new environment
echo "Copying VMChroot_Script.sh to /mnt..."
cp VMChroot_Script.sh /mnt
chmod +x /mnt/VMChroot_Script.sh

# Verify the script is copied successfully
if [ ! -f /mnt/VMChroot_Script.sh ]; then
    echo "Error: VMChroot_Script.sh not found in /mnt"
    exit 1
fi

# Chrooting and executing the script
echo "Chrooting into new env and executing VMChroot_Script.sh..."
arch-chroot /mnt /bin/bash -c "cd && ./VMChroot_Script.sh"

# Unmount EFI partition and clean up
echo "Unmounting EFI partition and cleaning up..."
umount -R /mnt   # Unmount all mounted partitions

# Prompt to reboot
echo "Please reboot your system to apply changes."
