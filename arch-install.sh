#!/bin/bash

# Скрипт установки Arch Linux с KDE и поддержкой Windows приложений
# ВНИМАНИЕ: Запускать только после базовой установки Arch Linux и загрузки в установленную систему

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Обновление системы
update_system() {
    print_info "Обновление системы..."
    pacman -Syu --noconfirm
}

# Установка базовых пакетов
install_base_packages() {
    print_info "Установка базовых пакетов..."
    pacman -S --noconfirm \
        base-devel \
        git \
        curl \
        wget \
        zip \
        unzip \
        p7zip \
        neofetch \
        htop \
        tree \
        rsync \
        openssh \
        sudo \
        dosfstools \
        ntfs-3g \
        exfat-utils \
        fuse \
        fuse2 \
        fuse3
}

# Установка графической оболочки KDE
install_kde() {
    print_info "Установка KDE Plasma..."
    pacman -S --noconfirm \
        plasma \
        kde-applications \
        sddm \
        xorg-server \
        xorg-xinit \
        xorg-xrandr \
        xorg-xset \
        xorg-xinput \
        mesa \
        vulkan-radeon \
        vulkan-intel \
        nvidia \
        nvidia-utils \
        nvidia-settings \
        alsa-utils \
        pulseaudio \
        pulseaudio-alsa \
        pavucontrol
    
    # Включение SDDM
    systemctl enable sddm
    systemctl enable NetworkManager
}

# Установка шрифтов
install_fonts() {
    print_info "Установка шрифтов..."
    pacman -S --noconfirm \
        ttf-dejavu \
        ttf-liberation \
        noto-fonts \
        noto-fonts-cjk \
        noto-fonts-emoji \
        ttf-roboto \
        ttf-roboto-mono \
        ttf-fira-code \
        ttf-font-awesome \
        adobe-source-code-pro-fonts
}

# Установка Wine и зависимостей для Windows приложений
install_wine_support() {
    print_info "Установка Wine и зависимостей..."
    
    # Мультимедиа кодеки
    pacman -S --noconfirm \
        gst-libav \
        gst-plugins-bad \
        gst-plugins-base \
        gst-plugins-good \
        gst-plugins-ugly \
        gstreamer-vaapi
    
    # Wine и зависимости
    pacman -S --noconfirm \
        wine \
        wine-gecko \
        wine-mono \
        winetricks \
        lib32-mesa \
        lib32-vulkan-radeon \
        lib32-vulkan-intel \
        lib32-libva \
        lib32-libva-mesa-driver \
        lib32-mesa-vdpau \
        lib32-vulkan-icd-loader \
        vulkan-icd-loader
    
    # Дополнительные библиотеки для совместимости
    pacman -S --noconfirm \
        lib32-alsa-plugins \
        lib32-libpulse \
        lib32-opencl-icd-loader \
        lib32-gcc-libs \
        lib32-libx11 \
        lib32-libxss \
        ocl-icd \
        opencl-headers
}

# Установка Bottles и Wine GUI
install_bottles() {
    print_info "Установка Bottles и дополнительных утилит..."
    
    # Установка через AUR (требуется yay)
    if ! command -v yay &> /dev/null; then
        print_info "Установка yay..."
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        cd /tmp/yay
        makepkg -si --noconfirm
        cd /
    fi
    
    # Установка Bottles и других утилит
    yay -S --noconfirm \
        bottles \
        lutris \
        playonlinux
    
    # Альтернатива: установка из официальных репозиториев (если доступно)
    # pacman -S --noconfirm bottles
}

# Установка игровых утилит
install_gaming_utils() {
    print_info "Установка игровых утилит..."
    
    # Steam и зависимости
    pacman -S --noconfirm \
        steam \
        gamemode \
        lib32-gamemode \
        gamescope
    
    # Дополнительные игровые утилиты
    yay -S --noconfirm \
        protonup-qt \
        protontricks \
        wine-staging \
        dxvk-bin \
        vkd3d-proton-bin
}

# Установка дополнительного ПО
install_additional_software() {
    print_info "Установка дополнительного ПО..."
    
    # Браузеры
    pacman -S --noconfirm \
        firefox \
        firefox-i18n-ru \
        chromium
    
    # Офисные приложения
    pacman -S --noconfirm \
        libreoffice-fresh \
        libreoffice-fresh-ru \
        okular \
        gimp \
        inkscape
    
    # Мультимедиа
    pacman -S --noconfirm \
        vlc \
        audacity \
        obs-studio
    
    # Утилиты
    pacman -S --noconfirm \
        filezilla \
        transmission-qt \
        keepassxc \
        spectacle \
        kate
}

# Настройка пользователя
setup_user() {
    print_info "Настройка пользователя..."
    
    if [[ -z "$SUDO_USER" ]]; then
        read -p "Введите имя пользователя для настройки: " username
    else
        username="$SUDO_USER"
    fi
    
    # Добавление пользователя в необходимые группы
    usermod -a -G wheel,audio,video,storage,optical "$username"
    
    # Настройка sudo
    if ! grep -q "^%wheel ALL=(ALL) ALL" /etc/sudoers; then
        echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
    fi
}

# Настройка локалей
setup_locale() {
    print_info "Настройка локалей..."
    
    # Русская локаль
    if ! grep -q "ru_RU.UTF-8 UTF-8" /etc/locale.gen; then
        echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
        echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    fi
    
    locale-gen
    echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
}

# Создание конфигурационных файлов
create_configs() {
    print_info "Создание базовых конфигураций..."
    
    # Настройка Wine
    sudo -u "$SUDO_USER" WINEPREFIX=~/.wine winecfg &>/dev/null || true
    
    # Создание директорий пользователя
    sudo -u "$SUDO_USER" xdg-user-dirs-update
}

# Финальные настройки
final_setup() {
    print_info "Выполнение финальных настроек..."
    
    # Включение служб
    systemctl enable bluetooth
    systemctl enable cups
    
    # Установка времени
    timedatectl set-ntp true
    
    print_info "Установка завершена!"
    print_warning "Перезагрузите систему командой: reboot"
    print_info "После перезагрузки вы сможете:"
    print_info "1. Использовать Bottles для запуска Windows приложений"
    print_info "2. Использовать Steam для игр"
    print_info "3. Настроить Wine через winecfg"
    print_info "4. Использовать Winetricks для установки компонентов Windows"
}

# Главная функция
main() {
    print_info "Начало установки Arch Linux с KDE и поддержкой Windows приложений"
    
    check_root
    update_system
    install_base_packages
    install_kde
    install_fonts
    install_wine_support
    install_bottles
    install_gaming_utils
    install_additional_software
    setup_user
    setup_locale
    create_configs
    final_setup
}

# Запуск скрипта
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
