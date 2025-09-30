#!/bin/bash

# Полный скрипт установки Arch Linux с нуля
# ВНИМАНИЕ: Этот скрипт полностью очистит диск! Используйте с осторожностью!

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Переменные
DRIVE="/dev/sda"
BOOT_PARTITION="${DRIVE}1"
ROOT_PARTITION="${DRIVE}2"
USERNAME="archuser"
HOSTNAME="archlinux"
TIMEZONE="Europe/Moscow"

# Функции для вывода
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен быть запущен с правами root"
        exit 1
    fi
}

# Предупреждение о разрушительных действиях
show_warning() {
    print_warning "ВНИМАНИЕ! Этот скрипт:"
    print_warning "1. Полностью очистит диск $DRIVE"
    print_warning "2. Удалит все данные на диске"
    print_warning "3. Установит Arch Linux с KDE"
    echo
    read -p "Вы уверены, что хотите продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Установка отменена"
        exit 1
    fi
}

# Проверка подключения к интернету
check_internet() {
    print_info "Проверка подключения к интернету..."
    if ! ping -c 1 archlinux.org &> /dev/null; then
        print_error "Нет подключения к интернету. Проверьте сеть."
        exit 1
    fi
}

# Синхронизация времени
sync_time() {
    print_info "Синхронизация времени..."
    timedatectl set-ntp true
    sleep 5
}

# Разметка диска
partition_disk() {
    print_info "Разметка диска $DRIVE..."
    
    # Очистка диска
    wipefs -a "$DRIVE"
    
    # Создание разделов
    # EFI раздел (512M) + Root раздел (оставшееся место)
    parted -s "$DRIVE" mklabel gpt
    parted -s "$DRIVE" mkpart primary fat32 1MiB 513MiB
    parted -s "$DRIVE" set 1 esp on
    parted -s "$DRIVE" mkpart primary ext4 513MiB 100%
    
    # Форматирование разделов
    mkfs.fat -F32 "$BOOT_PARTITION"
    mkfs.ext4 -F "$ROOT_PARTITION"
}

# Монтирование разделов
mount_partitions() {
    print_info "Монтирование разделов..."
    mount "$ROOT_PARTITION" /mnt
    mkdir -p /mnt/boot
    mount "$BOOT_PARTITION" /mnt/boot
}

# Установка базовой системы
install_base_system() {
    print_info "Установка базовой системы..."
    pacstrap /mnt base base-devel linux linux-firmware sudo nano git
}

# Генерация fstab
generate_fstab() {
    print_info "Генерация fstab..."
    genfstab -U /mnt >> /mnt/fstab
}

# Настройка системы
configure_system() {
    print_info "Настройка системы..."
    
    # Создание скрипта для выполнения внутри chroot
    cat > /mnt/setup-chroot.sh << 'EOF'
#!/bin/bash

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Переменные (должны быть такие же как в основном скрипте)
USERNAME="archuser"
HOSTNAME="archlinux"
TIMEZONE="Europe/Moscow"

# Настройка времени
print_info "Настройка времени..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Настройка локалей
print_info "Настройка локалей..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Настройка клавиатуры
echo "KEYMAP=ru" > /etc/vconsole.conf

# Настройка хоста
print_info "Настройка хоста..."
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOL

# Настройка пароля root
print_info "Установка пароля root..."
echo "Введите пароль для root:"
passwd

# Создание пользователя
print_info "Создание пользователя $USERNAME..."
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Введите пароль для пользователя $USERNAME:"
passwd "$USERNAME"

# Настройка sudo
print_info "Настройка sudo..."
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Установка загрузчика
print_info "Установка загрузчика..."
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Включение сетевых служб
print_info "Включение сетевых служб..."
systemctl enable NetworkManager

# Установка дополнительных пакетов
print_info "Установка дополнительных пакетов..."
pacman -S --noconfirm \
    networkmanager \
    wireless_tools \
    wpa_supplicant \
    dialog \
    mtools \
    dosfstools \
    linux-headers

EOF

    chmod +x /mnt/setup-chroot.sh
    arch-chroot /mnt ./setup-chroot.sh
}

# Установка графической оболочки и программ
install_desktop_environment() {
    print_info "Установка KDE Plasma и дополнительного ПО..."
    
    cat > /mnt/setup-desktop.sh << 'EOF'
#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

USERNAME="archuser"

# Обновление системы
print_info "Обновление системы..."
pacman -Syu --noconfirm

# Установка Xorg
print_info "Установка Xorg..."
pacman -S --noconfirm xorg xorg-server xorg-xinit xorg-xrandr

# Установка KDE Plasma
print_info "Установка KDE Plasma..."
pacman -S --noconfirm plasma-desktop sddm konsole dolphin kate

# Установка сетевого менеджера для KDE
pacman -S --noconfirm plasma-nm

# Включение SDDM
systemctl enable sddm

# Установка дополнительных приложений KDE
print_info "Установка приложений KDE..."
pacman -S --noconfirm \
    kde-applications \
    firefox \
    firefox-i18n-ru \
    chromium

# Установка мультимедиа кодеков
print_info "Установка кодеков..."
pacman -S --noconfirm \
    gst-libav \
    gst-plugins-bad \
    gst-plugins-base \
    gst-plugins-good \
    gst-plugins-ugly

# Установка шрифтов
print_info "Установка шрифтов..."
pacman -S --noconfirm \
    ttf-dejavu \
    ttf-liberation \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-roboto \
    ttf-fira-code

EOF

    chmod +x /mnt/setup-desktop.sh
    arch-chroot /mnt ./setup-desktop.sh
}

# Установка Wine и поддержки Windows приложений
install_wine_support() {
    print_info "Установка Wine и поддержки Windows приложений..."
    
    cat > /mnt/setup-wine.sh << 'EOF'
#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

USERNAME="archuser"

# Установка Wine и зависимостей
print_info "Установка Wine..."
pacman -S --noconfirm \
    wine \
    wine-gecko \
    wine-mono \
    winetricks \
    lib32-mesa \
    vulkan-radeon \
    vulkan-intel \
    lib32-vulkan-radeon \
    lib32-vulkan-intel

# Установка дополнительных библиотек
print_info "Установка дополнительных библиотек..."
pacman -S --noconfirm \
    lib32-alsa-plugins \
    lib32-libpulse \
    lib32-opencl-icd-loader \
    lib32-gcc-libs \
    ocl-icd

# Установка yay (AUR helper)
print_info "Установка yay..."
sudo -u $USERNAME bash << EOU
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd /
rm -rf /tmp/yay
EOU

# Установка Bottles из AUR
print_info "Установка Bottles..."
sudo -u $USERNAME yay -S --noconfirm bottles

# Установка игровых утилит
print_info "Установка игровых утилит..."
pacman -S --noconfirm steam

sudo -u $USERNAME yay -S --noconfirm \
    protonup-qt \
    dxvk-bin \
    vkd3d-proton-bin

# Установка дополнительного ПО
print_info "Установка дополнительного ПО..."
pacman -S --noconfirm \
    vlc \
    libreoffice-fresh \
    libreoffice-fresh-ru \
    gimp \
    obs-studio \
    telegram-desktop \
    keepassxc

EOF

    chmod +x /mnt/setup-wine.sh
    arch-chroot /mnt ./setup-wine.sh
}

# Финальная настройка
final_setup() {
    print_info "Финальная настройка..."
    
    # Очистка
    rm -f /mnt/setup-chroot.sh /mnt/setup-desktop.sh /mnt/setup-wine.sh
    
    # Создание автоматического скрипта для первого входа
    cat > /mnt/home/$USERNAME/first-setup.sh << 'EOF'
#!/bin/bash

echo "Выполнение финальных настроек..."

# Настройка Wine
echo "Настройка Wine..."
WINEPREFIX=~/.wine winecfg &>/dev/null &

# Установка дополнительных компонентов через Winetricks
echo "Установка компонентов Windows..."
winetricks -q corefonts vcrun2019 dotnet48 &>/dev/null &

# Создание ярлыков
cat > ~/Desktop/bottles.desktop << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Bottles
Comment=Run Windows applications
Exec=bottles
Icon=com.usebottles.bottles
Terminal=false
Categories=Utility;
EOL

chmod +x ~/Desktop/bottles.desktop

echo "Настройка завершена!"
echo "Перезагрузите систему и войдите под пользователем $USERNAME"
EOF

    chmod +x /mnt/home/$USERNAME/first-setup.sh
    chown $USERNAME:$USERNAME /mnt/home/$USERNAME/first-setup.sh
}

# Главная функция
main() {
    print_info "Начало установки Arch Linux с нуля"
    
    check_root
    show_warning
    check_internet
    sync_time
    partition_disk
    mount_partitions
    install_base_system
    generate_fstab
    configure_system
    install_desktop_environment
    install_wine_support
    final_setup
    
    print_info "Установка завершена!"
    print_info "Перезагрузите систему командой: umount -R /mnt && reboot"
    print_info "После перезагрузки войдите под пользователем: $USERNAME"
    print_info "Запустите финальную настройку: ~/first-setup.sh"
}

# Запуск скрипта
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
