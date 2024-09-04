#!/bin/bash

# Open /etc/pacman.conf for editing and uncomment multilib section
sudo sed -i "/\[multilib\]/,/Include/"' s/^#//' /etc/pacman.conf    
echo "Multilib repository enabled!"

# Update package database to include multilib
sudo pacman -Syu --noconfirm

# Install KDE Plasma Desktop and additional packages
echo "Installing KDE Plasma Desktop and additional packages..."
sudo pacman -S --noconfirm plasma-meta plasma-workspace ark konsole dolphin egl-wayland kdeconnect

# Install display manager (SDDM)
echo "Installing SDDM display manager..."
sudo pacman -S --noconfirm sddm

# Enable and start display manager
echo "Enabling and starting SDDM..."
sudo systemctl enable sddm.service
sudo systemctl start sddm.service

echo "KDE Plasma Desktop installation completed!"

# Install necessary packages for yay
sudo pacman -S --noconfirm curl zsh pacman-contrib git base-devel firefox vim neovim vlc discord libreoffice mpv telegram-desktop spectacle

# Install paru from AUR
echo "Installing paru from AUR..."
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm

paru -S --noconfirm google-chrome visual-studio-code-bin postman-bin mongodb-compass balena-etcher tor-browser-bin

# Prompt user for NVIDIA driver installation
read -p "Do you want to install NVIDIA driver (y/n)? " choice
if [[ $choice == [Yy] ]]; then
    # Install NVIDIA driver and related packages
    echo "Installing NVIDIA driver and utilities..."
    sudo pacman -S --noconfirm nvidia nvidia-utils nvtop
else
    echo "Skipping NVIDIA driver installation."
fi

# Prompt user for Steam installation
read -p "Do you want to install Steam? (y/n): " install_steam
if [[ $install_steam =~ ^[Yy]$ ]]; then
    # Install Steam from multilib repository
    echo "Installing Steam..."
    sudo pacman -S --noconfirm steam
else
    echo "Skipping Steam installation."
fi

# Prompt user for VirtualBox installation
read -p "Do you want to install Oracle VirtualBox? (y/n): " install_virtualbox
if [[ $install_virtualbox =~ ^[Yy]$ ]]; then
    # Install VirtualBox and related packages
    echo "Installing Oracle VirtualBox..."
    sudo pacman -S --noconfirm virtualbox virtualbox-host-modules-arch virtualbox-guest-iso linux-headers
    modprobe vboxdrv
else
    echo "Skipping Oracle VirtualBox installation."
fi


# Install Oh My Zsh
echo "Installing Oh My Zsh..."
sudo pacman -S --noconfirm curl
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Oh My Zsh installed and configured!"

echo "Setup completed!"
