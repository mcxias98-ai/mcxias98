#!/bin/bash

# ============================================
# Интерактивный установщик Arch Linux
# Версия: 2.0
# ============================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Переменные для выбора пакетов
SELECTED_DE=""
SELECTED_DM=""
SELECTED_DRIVER=""
INSTALL_XORG=false
INSTALL_FONTS=false
INSTALL_NETWORK_MANAGER=false
PACKAGES=""

# Функции для цветного вывода
print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_step() {
    echo -e "${MAGENTA}► $1${NC}"
}

print_warning() {
    echo -e "${RED}⚠ $1${NC}"
}

# Функция для запроса подтверждения
confirm() {
    while true; do
        read -p "$(echo -e ${YELLOW}"$1 (y/N): "${NC})" yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            "" ) return 1;;
            * ) echo "Пожалуйста, ответьте y или n.";;
        esac
    done
}

# Функция для выбора из списка
select_option() {
    local options=("$@")
    local choice
    
    for i in "${!options[@]}"; do
        echo "$((i+1))) ${options[i]}"
    done
    
    while true; do
        read -p "$(echo -e ${YELLOW}"Выберите вариант (1-${#options[@]}): "${NC})" choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice-1))]}"
            return
        else
            print_error "Неверный выбор. Пожалуйста, выберите от 1 до ${#options[@]}"
        fi
    done
}

# Функция для проверки подключения к интернету
check_internet() {
    print_step "Проверка подключения к интернету..."
    
    local hosts=("8.8.8.8" "1.1.1.1" "google.com" "archlinux.org")
    local connected=false
    
    for host in "${hosts[@]}"; do
        if ping -c 2 -W 2 "$host" &>/dev/null; then
            connected=true
            print_success "Подключение к интернету установлено (через $host)"
            break
        fi
        sleep 1
    done
    
    if [ "$connected" = false ]; then
        print_warning "Интернет не доступен!"
        return 1
    fi
    
    return 0
}

# Функция настройки сети
setup_network() {
    print_header "НАСТРОЙКА СЕТИ"
    
    print_info "Доступные сетевые интерфейсы:"
    ip link show | grep -E "^[0-9]+:" | awk '{print "  " $2}' | sed 's/://g'
    
    echo ""
    print_step "Выберите способ настройки сети:"
    echo "  1) DHCP (автоматическая настройка)"
    echo "  2) Статический IP"
    echo "  3) Wi-Fi (iwctl)"
    echo "  4) Пропустить (настроить вручную позже)"
    
    read -p "$(echo -e ${YELLOW}"Выберите вариант (1-4): "${NC})" net_choice
    
    case $net_choice in
        1)
            print_step "Настройка DHCP..."
            if systemctl start dhcpcd &>/dev/null || dhcpcd &>/dev/null; then
                print_success "DHCP настроен успешно"
            else
                print_warning "Не удалось запустить dhcpcd, попробуйте настроить вручную"
            fi
            ;;
        2)
            print_step "Настройка статического IP..."
            read -p "$(echo -e ${YELLOW}"Введите имя интерфейса (например, enp0s3): "${NC})" iface
            read -p "$(echo -e ${YELLOW}"Введите IP-адрес (например, 192.168.1.100/24): "${NC})" ipaddr
            read -p "$(echo -e ${YELLOW}"Введите шлюз (например, 192.168.1.1): "${NC})" gateway
            read -p "$(echo -e ${YELLOW}"Введите DNS-сервер (например, 8.8.8.8): "${NC})" dns
            
            ip addr add "$ipaddr" dev "$iface"
            ip link set "$iface" up
            ip route add default via "$gateway"
            echo "nameserver $dns" > /etc/resolv.conf
            
            print_success "Статический IP настроен"
            ;;
        3)
            print_step "Настройка Wi-Fi..."
            if command -v iwctl &>/dev/null; then
                print_info "Запуск iwctl для настройки Wi-Fi..."
                print_info "Инструкция:"
                echo "  device list - показать устройства"
                echo "  station wlan0 scan - сканировать сети"
                echo "  station wlan0 connect SSID - подключиться к сети"
                echo "  exit - выйти из iwctl"
                echo ""
                iwctl
            else
                print_error "iwctl не найден. Попробуйте использовать wifi-menu или iwconfig"
                if command -v wifi-menu &>/dev/null; then
                    wifi-menu
                fi
            fi
            ;;
        4)
            print_info "Настройка сети пропущена"
            return
            ;;
        *)
            print_error "Неверный выбор"
            setup_network
            return
            ;;
    esac
    
    if check_internet; then
        print_success "Сеть настроена успешно!"
        
        print_step "Синхронизация времени..."
        if timedatectl set-ntp true &>/dev/null; then
            print_success "Время синхронизировано"
        else
            print_warning "Не удалось синхронизировать время"
        fi
    else
        print_warning "Проверьте настройки сети и попробуйте снова"
        if confirm "Повторить настройку сети?"; then
            setup_network
        fi
    fi
}

# Функция настройки локализации
setup_locale() {
    print_header "НАСТРОЙКА ЛОКАЛИЗАЦИИ"
    
    print_step "Настройка русской локализации..."
    
    echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    
    locale-gen &>/dev/null
    
    export LANG=ru_RU.UTF-8
    echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
    
    print_step "Настройка раскладки клавиатуры..."
    echo "KEYMAP=ru" >> /etc/vconsole.conf
    echo "FONT=cyr-sun16" >> /etc/vconsole.conf
    
    loadkeys ru &>/dev/null
    
    print_success "Русская локализация настроена"
}

# Функция выбора пакетов
select_packages() {
    print_header "ВЫБОР ПАКЕТОВ ДЛЯ УСТАНОВКИ"
    
    # Базовые пакеты (всегда устанавливаются)
    BASE_PACKAGES="base base-devel linux linux-firmware linux-headers nano vim konsole bash-completion grub efibootmgr"
    PACKAGES="$BASE_PACKAGES"
    
    print_info "Базовые пакеты (будут установлены всегда):"
    echo "  $BASE_PACKAGES"
    echo ""
    
    # Выбор дисплейного сервера Xorg
    if confirm "Установить Xorg (дисплейный сервер)?"; then
        INSTALL_XORG=true
        PACKAGES="$PACKAGES xorg"
        print_success "Xorg будет установлен"
    else
        print_info "Xorg не будет установлен"
    fi
    echo ""
    
    # Выбор шрифтов
    if confirm "Установить дополнительные шрифты (Ubuntu, Hack, DejaVu, OpenSans)?"; then
        INSTALL_FONTS=true
        PACKAGES="$PACKAGES ttf-ubuntu-font-family ttf-hack ttf-dejavu ttf-opensans"
        print_success "Шрифты будут установлены"
    else
        print_info "Дополнительные шрифты не будут установлены"
    fi
    echo ""
    
    # Выбор менеджера входа
    if [ "$INSTALL_XORG" = true ]; then
        print_step "Выберите дисплейный менеджер:"
        DM_OPTIONS=("sddm" "lightdm" "lxdm" "gdm" "Пропустить")
        SELECTED_DM=$(select_option "${DM_OPTIONS[@]}")
        
        if [ "$SELECTED_DM" != "Пропустить" ]; then
            PACKAGES="$PACKAGES $SELECTED_DM"
            print_success "Выбран дисплейный менеджер: $SELECTED_DM"
        else
            print_info "Дисплейный менеджер не выбран"
        fi
        echo ""
    fi
    
    # Выбор окружения рабочего стола
    if [ "$INSTALL_XORG" = true ]; then
        print_step "Выберите окружение рабочего стола:"
        DE_OPTIONS=("gnome" "plasma" "cinnamon" "budgie" "xfce4" "lxqt" "lxde" "Пропустить")
        SELECTED_DE=$(select_option "${DE_OPTIONS[@]}")
        
        if [ "$SELECTED_DE" != "Пропустить" ]; then
            # Добавляем пакеты в зависимости от выбранного DE
            case $SELECTED_DE in
                "gnome")
                    PACKAGES="$PACKAGES gnome gnome-extra"
                    ;;
                "plasma")
                    PACKAGES="$PACKAGES plasma-meta kde-applications-meta"
                    ;;
                "cinnamon")
                    PACKAGES="$PACKAGES cinnamon nemo-fileroller"
                    ;;
                "budgie")
                    PACKAGES="$PACKAGES budgie-desktop budgie-extras"
                    ;;
                "xfce4")
                    PACKAGES="$PACKAGES xfce4 xfce4-goodies"
                    ;;
                "lxqt")
                    PACKAGES="$PACKAGES lxqt lxqt-config"
                    ;;
                "lxde")
                    PACKAGES="$PACKAGES lxde"
                    ;;
            esac
            print_success "Выбрано окружение: $SELECTED_DE"
        else
            print_info "Окружение рабочего стола не выбрано"
        fi
        echo ""
    fi
    
    # Выбор драйвера NVIDIA
    if confirm "Установить проприетарный драйвер NVIDIA?"; then
        SELECTED_DRIVER="nvidia"
        PACKAGES="$PACKAGES nvidia nvidia-utils nvidia-settings"
        print_success "Драйвер NVIDIA будет установлен"
    else
        print_info "Драйвер NVIDIA не будет установлен"
    fi
    echo ""
    
    # Выбор NetworkManager
    if confirm "Установить NetworkManager (для управления сетью)?"; then
        INSTALL_NETWORK_MANAGER=true
        PACKAGES="$PACKAGES networkmanager network-manager-applet"
        print_success "NetworkManager будет установлен"
    else
        print_info "NetworkManager не будет установлен"
    fi
    echo ""
    
    # Вывод итогового списка
    print_header "ИТОГОВЫЙ СПИСОК ПАКЕТОВ"
    echo -e "${CYAN}$PACKAGES${NC}"
    echo ""
    
    if ! confirm "Продолжить с этим списком пакетов?"; then
        print_info "Повторный выбор пакетов..."
        select_packages
        return
    fi
}

# Функция разметки диска
disk_partitioning() {
    print_header "РАЗМЕТКА ДИСКА"
    
    print_info "Доступные диски:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL | grep -E "disk|part"
    
    echo ""
    read -p "$(echo -e ${YELLOW}"Введите диск для установки (например, /dev/sda): "${NC})" disk
    
    if [ ! -b "$disk" ]; then
        print_error "Диск $disk не найден"
        disk_partitioning
        return
    fi
    
    print_warning "ВНИМАНИЕ! Все данные на диске $disk будут удалены!"
    if ! confirm "Вы уверены, что хотите продолжить?"; then
        disk_partitioning
        return
    fi
    
    print_step "Создание разделов на диске $disk..."
    
    wipefs -a "$disk" &>/dev/null
    dd if=/dev/zero of="$disk" bs=1M count=10 &>/dev/null
    
    parted -s "$disk" mklabel gpt
    
    if [ -d /sys/firmware/efi ]; then
        print_info "Обнаружена UEFI система"
        parted -s "$disk" mkpart primary fat32 1MiB 513MiB
        parted -s "$disk" set 1 esp on
        parted -s "$disk" mkpart primary ext4 513MiB 100%
        
        mkfs.fat -F32 "${disk}1" &>/dev/null
        mkfs.ext4 -F "${disk}2" &>/dev/null
        
        mount "${disk}2" /mnt
        mkdir -p /mnt/boot/efi
        mount "${disk}1" /mnt/boot/efi
        
        print_success "Разделы созданы (UEFI)"
    else
        print_info "Обнаружена BIOS/Legacy система"
        parted -s "$disk" mkpart primary ext4 1MiB 100%
        parted -s "$disk" set 1 boot on
        
        mkfs.ext4 -F "${disk}1" &>/dev/null
        
        mount "${disk}1" /mnt
        
        print_success "Разделы созданы (BIOS)"
    fi
    
    print_success "Разметка диска завершена"
}

# Функция установки базовой системы
install_base() {
    print_header "УСТАНОВКА БАЗОВОЙ СИСТЕМЫ"
    
    print_step "Выбор зеркал для загрузки..."
    if command -v reflector &>/dev/null; then
        reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null
        print_success "Зеркала обновлены через reflector"
    fi
    
    print_step "Установка базовых пакетов..."
    print_info "Устанавливаются пакеты: $PACKAGES"
    
    if pacstrap /mnt $PACKAGES; then
        print_success "Базовая система установлена"
    else
        print_error "Ошибка при установке базовой системы"
        exit 1
    fi
    
    print_step "Генерация fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    print_success "fstab сгенерирован"
}

# Функция конфигурации системы
configure_system() {
    print_header "КОНФИГУРАЦИЯ СИСТЕМЫ"
    
    # Запрос имени хоста
    read -p "$(echo -e ${YELLOW}"Введите имя хоста: "${NC})" hostname
    echo "$hostname" > /mnt/etc/hostname
    
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain $hostname
EOF
    
    # Настройка времени
    read -p "$(echo -e ${YELLOW}"Введите часовой пояс (например, Europe/Moscow): "${NC})" timezone
    arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime &>/dev/null
    
    # Настройка локали
    echo "ru_RU.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    arch-chroot /mnt locale-gen &>/dev/null
    
    echo "LANG=ru_RU.UTF-8" > /mnt/etc/locale.conf
    
    echo "KEYMAP=ru" > /mnt/etc/vconsole.conf
    
    # Установка пароля root
    print_step "Установка пароля root:"
    arch-chroot /mnt passwd
    
    # Создание пользователя
    if confirm "Создать пользователя?"; then
        read -p "$(echo -e ${YELLOW}"Введите имя пользователя: "${NC})" username
        arch-chroot /mnt useradd -m -G wheel,users "$username"
        arch-chroot /mnt passwd "$username"
        
        echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers
    fi
    
    # Настройка NetworkManager
    if [ "$INSTALL_NETWORK_MANAGER" = true ]; then
        print_step "Настройка NetworkManager..."
        arch-chroot /mnt systemctl enable NetworkManager &>/dev/null
        print_success "NetworkManager включен в автозагрузку"
    fi
    
    # Настройка дисплейного менеджера
    if [ "$SELECTED_DM" != "Пропустить" ] && [ "$SELECTED_DM" != "" ]; then
        print_step "Настройка дисплейного менеджера $SELECTED_DM..."
        arch-chroot /mnt systemctl enable "$SELECTED_DM" &>/dev/null
        print_success "$SELECTED_DM включен в автозагрузку"
    fi
    
    # Установка загрузчика
    print_step "Установка загрузчика..."
    
    if [ -d /sys/firmware/efi ]; then
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB &>/dev/null
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
        print_success "GRUB установлен (UEFI)"
    else
        arch-chroot /mnt grub-install --target=i386-pc "$disk" &>/dev/null
        arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
        print_success "GRUB установлен (BIOS)"
    fi
    
    # Настройка NVIDIA (если установлен)
    if [ "$SELECTED_DRIVER" = "nvidia" ]; then
        print_step "Настройка NVIDIA драйвера..."
        # Добавляем модуль nvidia в mkinitcpio
        arch-chroot /mnt sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        arch-chroot /mnt mkinitcpio -p linux &>/dev/null
        print_success "NVIDIA драйвер настроен"
    fi
}

# Главная функция
main() {
    clear
    print_header "АРХ ЛИНУКС - ИНТЕРАКТИВНАЯ УСТАНОВКА"
    echo -e "${WHITE}Добро пожаловать в интерактивный установщик Arch Linux!${NC}"
    echo -e "${WHITE}Этот скрипт поможет вам установить Arch Linux с нуля.${NC}\n"
    
    # Проверка прав
    if [ "$EUID" -ne 0 ]; then
        print_error "Этот скрипт должен запускаться от root"
        exit 1
    fi
    
    # Настройка локализации
    setup_locale
    
    # Настройка сети
    if ! check_internet; then
        setup_network
    fi
    
    # Проверка режима загрузки
    if [ -d /sys/firmware/efi ]; then
        print_success "Система загружена в режиме UEFI"
    else
        print_info "Система загружена в режиме BIOS/Legacy"
    fi
    
    # Выбор пакетов
    select_packages
    
    # Разметка диска
    disk_partitioning
    
    # Установка базовой системы
    install_base
    
    # Конфигурация системы
    configure_system
    
    # Финальные шаги
    print_header "УСТАНОВКА ЗАВЕРШЕНА"
    print_success "Arch Linux успешно установлен!"
    print_info "Установлены пакеты: $PACKAGES"
    
    if [ "$SELECTED_DE" != "Пропустить" ] && [ "$SELECTED_DE" != "" ]; then
        print_info "Окружение рабочего стола: $SELECTED_DE"
    fi
    
    if [ "$SELECTED_DM" != "Пропустить" ] && [ "$SELECTED_DM" != "" ]; then
        print_info "Дисплейный менеджер: $SELECTED_DM"
    fi
    
    if [ "$SELECTED_DRIVER" = "nvidia" ]; then
        print_info "Установлен драйвер NVIDIA"
    fi
    
    echo ""
    print_info "Не забудьте перезагрузить систему и извлечь установочный носитель"
    
    if confirm "Перезагрузить систему сейчас?"; then
        umount -R /mnt 2>/dev/null
        reboot
    else
        print_info "Вы можете выйти из chroot и перезагрузить систему позже"
        print_info "Для выхода из chroot используйте: exit"
        print_info "Для перезагрузки: reboot"
    fi
}

# Запуск главной функции
main