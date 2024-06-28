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
parted $DISK --script mkpart primary ext4 513MiB 100%

# Format the partitions
echo "Formatting the partitions..."
mkfs.fat -F32 ${DISK}p1   # Format /boot partition as FAT32
mkfs.ext4 ${DISK}p2       # Format root partition as ext4

echo "Disk partitioning and formatting completed successfully."

# Mount the root partition
echo "Mounting the root partition..."
mount ${DISK}p2 /mnt

echo "Root partition mounted successfully."

# Install base system packages (base, linux, linux-firmware) into /mnt
pacstrap -K /mnt base linux linux-firmware

# Generate fstab file for the installed system
echo "Generating fstab file..."
genfstab -U /mnt >> /mnt/etc/fstab

# Provide confirmation message
echo "fstab file generated successfully."

# Chrooting 
echo "Chrooting into new env"
arch-chroot /mnt

# Set timezone to Asia/Kolkata
echo "Setting timezone to Asia/Kolkata..."
ln -sf /usr/share/zoneinfo/Asia/Kolkata /mnt/etc/localtime

# Provide confirmation message
echo "Timezone set to Asia/Kolkata successfully."

# Set hardware clock to synchronize with system time
echo "Setting hardware clock to synchronize with system time..."
hwclock --systohc

# Provide confirmation message
echo "Hardware clock set successfully."

# Edit /etc/locale.gen to uncomment en_US.UTF-8 UTF-8
echo "Uncommenting en_US.UTF-8 UTF-8 in /etc/locale.gen..."
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen

# Generate locales
echo "Generating locales..."
locale-gen

# Provide confirmation message
echo "Locales generated successfully."

# Create /etc/locale.conf and set LANG variable
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

# Provide confirmation message
echo "Created /etc/locale.conf and set LANG variable."

# Prompt user for hostname
read -p "Enter hostname: " hostname_input

# Set hostname in /etc/hostname
echo "$hostname_input" > /mnt/etc/hostname

# Provide confirmation message
echo "Created /etc/hostname with hostname: $hostname_input"

# Prompt user to set root password
echo "Setting root password:"
passwd

# Provide confirmation message
echo "Root password set successfully."

# Mount the EFI System Partition (ESP)
echo "Mounting EFI System Partition (ESP)..."
mkdir -p /mnt/boot/EFI   # Create mount point if not exist
mount /dev/nvme0n1p1 /mnt/boot/EFI   # Mount the EFI partition

# Install required packages
echo "Installing necessary packages..."
pacman -Sy grub efibootmgr efitools dosfstools mtools os-prober --noconfirm   # Install required packages

# Install GRUB for UEFI
echo "Installing GRUB for UEFI..."
grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB --verbose --recheck   # Install GRUB with verbose output and recheck

# Generate GRUB configuration file
echo "Generating GRUB configuration file..."
grub-mkconfig -o /boot/grub/grub.cfg   # Generate GRUB configuration file

# Provide completion message
echo "GRUB installation completed successfully."

# Prompt user to add a new user
read -p "Do you want to add a new user? (yes/no): " add_user_choice

if [ "$add_user_choice" = "yes" ]; then
    # Prompt for username
    read -p "Enter username for the new user: " username
    
    # Add the user
    echo "Adding user '$username'..."
    useradd -m -G audio,video,storage,games,optical $username   # Create user with home directory and add to groups
    
    # Set password for the user
    echo "Setting password for user '$username'..."
    passwd $username   # Set password for the user
    
    # Prompt to add user to sudoers file
    read -p "Do you want to add '$username' to sudoers file? (yes/no): " sudo_choice
    
    if [ "$sudo_choice" = "yes" ]; then
        # Install sudo package if not already installed
        pacman -Sy sudo --noconfirm   # Install sudo package
        
        # Add user to wheel group
        usermod -aG wheel $username   # Add user to wheel group
        
        # Check if %wheel line is uncommented in sudoers
        if ! grep -q "^%wheel" /etc/sudoers; then
            echo "Uncommenting %wheel line in sudoers file..."
            sed -i '/^# %wheel/s/^# //' /etc/sudoers   # Uncomment %wheel line in sudoers file
        else
            echo "The %wheel line is already uncommented in sudoers file."
        fi
    fi
    
    # Provide confirmation message
    echo "User '$username' added successfully."
fi

# Provide completion message
echo "Configuration completed successfully."

# Unmount EFI partition and clean up
echo "Unmounting EFI partition and cleaning up..."
umount -R /mnt   # Unmount all mounted partitions

# Prompt to reboot
echo "Please reboot your system to apply changes."
