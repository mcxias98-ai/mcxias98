#!/bin/bash

# Скрипт установки Arch Linux с Cinnamon
# Запускать из установочной среды Arch Linux

set -e # Прекратить выполнение при ошибке

# === КОНФИГУРАЦИЯ ===
DISK="/dev/sda" # Укажите ваш диск
HOSTNAME="archlinux"
USERNAME="user" # Имя пользователя
PASSWORD="password" # Пароль пользователя
ROOT_PASSWORD="rootpassword" # Пароль root
TIMEZONE="Europe/Moscow" # Часовой пояс
LOCALE="ru_RU.UTF-8" # Локаль

# === РАЗМЕТКА ДИСКА ===
echo "Разметка диска..."
parted -s $DISK mklabel msdos
parted -s $DISK mkpart primary ext4 1MiB 100%
parted -s $DISK set 1 boot on

# Форматирование
mkfs.ext4 ${DISK}1

# Монтирование
mount ${DISK}1 /mnt

# === УСТАНОВКА БАЗОВОЙ СИСТЕМЫ ===
echo "Установка базовой системы..."
pacstrap /mnt base base-devel linux linux-firmware

# Генерация fstab
genfstab -U /mnt >> /mnt/fstab

# === НАСТРОЙКА СИСТЕМЫ ===
echo "Настройка системы..."

# Chroot и выполнение команд в новой системе
arch-chroot /mnt /bin/bash <<EOF
# Установка часового пояса
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Настройка локали
echo "$LOCALE UTF-8" >> /etc/locale.gen
echo "LANG=$LOCALE" > /etc/locale.conf
locale-gen

# Настройка сети
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Установка загрузчика
pacman -S --noconfirm grub
grub-install $DISK
grub-mkconfig -o /boot/grub/grub.cfg

# Пароли
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Настройка sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Установка графической оболочки и доп. пакетов
pacman -S --noconfirm \
    cinnamon \
    lightdm \
    lightdm-gtk-greeter \
    xorg-server \
    xorg-xinit \
    networkmanager \
    sudo \
    konsole \
    kate \
    git \
    firefox \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji

# Включение служб
systemctl enable lightdm
systemctl enable NetworkManager

# Создание конфига Xorg для пользователя
sudo -u $USERNAME bash -c 'echo "exec cinnamon-session" > ~/.xinitrc'
EOF

# === ЗАВЕРШЕНИЕ ===
echo "Установка завершена!"
echo "Перезагрузите систему: umount -R /mnt && reboot"
