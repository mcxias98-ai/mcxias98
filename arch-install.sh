#!/bin/bash

# Скрипт автоматической установки Arch Linux с настройками пользователя
# ВНИМАНИЕ: Этот скрипт полностью уничтожит данные на выбранном диске!

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Переменные по умолчанию
HOSTNAME="archlinux"
USERNAME="archuser"
TIMEZONE="Europe/Moscow"
LANGUAGE="en_US.UTF-8"
ADDITIONAL_PACKAGES=""

# Функции для вывода
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_input() { echo -e "${CYAN}[INPUT]${NC} $1"; }

# Запрос данных у пользователя
get_user_input() {
    print_input "=== НАСТРОЙКА УСТАНОВКИ ==="
    
    # Имя компьютера
    read -p "Введите имя компьютера [по умолчанию: $HOSTNAME]: " input_hostname
    HOSTNAME=${input_hostname:-$HOSTNAME}
    
    # Имя пользователя
    read -p "Введите имя пользователя [по умолчанию: $USERNAME]: " input_username
    USERNAME=${input_username:-$USERNAME}
    
    # Пароль root
    while true; do
        read -sp "Введите пароль root: " root_password
        echo
        if [ -n "$root_password" ]; then
            read -sp "Повторите пароль root: " root_password_confirm
            echo
            if [ "$root_password" = "$root_password_confirm" ]; then
                break
            else
                print_error "Пароли не совпадают!"
            fi
        else
            print_error "Пароль не может быть пустым!"
        fi
    done
    
    # Пароль пользователя
    while true; do
        read -sp "Введите пароль для пользователя $USERNAME: " user_password
        echo
        if [ -n "$user_password" ]; then
            read -sp "Повторите пароль для пользователя $USERNAME: " user_password_confirm
            echo
            if [ "$user_password" = "$user_password_confirm" ]; then
                break
            else
                print_error "Пароли не совпадают!"
            fi
        else
            print_error "Пароль не может быть пустым!"
        fi
    done
    
    # Часовой пояс
    read -p "Введите часовой пояс [по умолчанию: $TIMEZONE]: " input_timezone
    TIMEZONE=${input_timezone:-$TIMEZONE}
    
    # Выбор загрузчика
    print_input "Выберите загрузчик:"
    echo "1) systemd-boot (рекомендуется для UEFI)"
    echo "2) GRUB (универсальный)"
    read -p "Введите номер [1-2]: " bootloader_choice
    case $bootloader_choice in
        1) BOOTLOADER="systemd-boot" ;;
        2) BOOTLOADER="grub" ;;
        *) BOOTLOADER="systemd-boot" ;;
    esac
    
    # Выбор графической оболочки
    print_input "Выберите графическую оболочку:"
    echo "1) GNOME"
    echo "2) KDE Plasma"
    echo "3) XFCE"
    echo "4) LXQt"
    echo "5) Cinnamon"
    echo "6) Только консоль (без графики)"
    read -p "Введите номер [1-6]: " de_choice
    case $de_choice in
        1) DE="gnome" ;;
        2) DE="kde" ;;
        3) DE="xfce" ;;
        4) DE="lxqt" ;;
        5) DE="cinnamon" ;;
        6) DE="none" ;;
        *) DE="none" ;;
    esac
    
    # Дополнительные пакеты
    print_input "Введите дополнительные пакеты для установки (через пробел):"
    print_info "Например: firefox vim git curl wget"
    read -p "Дополнительные пакеты: " ADDITIONAL_PACKAGES
    
    # Подтверждение
    echo
    print_warning "=== ПОДТВЕРЖДЕНИЕ НАСТРОЕК ==="
    echo "Имя компьютера: $HOSTNAME"
    echo "Имя пользователя: $USERNAME"
    echo "Часовой пояс: $TIMEZONE"
    echo "Загрузчик: $BOOTLOADER"
    echo "Графическая оболочка: $DE"
    echo "Дополнительные пакеты: $ADDITIONAL_PACKAGES"
    echo
    read -p "Продолжить установку? (y/N): " final_confirm
    
    if [[ $final_confirm != "y" && $final_confirm != "Y" ]]; then
        print_info "Установка отменена"
        exit 0
    fi
}

# Функция для выбора графической оболочки
get_de_packages() {
    case $DE in
        "gnome")
            DE_PACKAGES="gnome gnome-extra gdm"
            DM_SERVICE="gdm"
            ;;
        "kde")
            DE_PACKAGES="plasma plasma-meta plasma-wayland-session sddm"
            DM_SERVICE="sddm"
            ;;
        "xfce")
            DE_PACKAGES="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
            DM_SERVICE="lightdm"
            ;;
        "lxqt")
            DE_PACKAGES="lxqt sddm"
            DM_SERVICE="sddm"
            ;;
        "cinnamon")
            DE_PACKAGES="cinnamon lightdm lightdm-gtk-greeter"
            DM_SERVICE="lightdm"
            ;;
        "none")
            DE_PACKAGES=""
            DM_SERVICE=""
            ;;
    esac
}

# Проверка на UEFI
check_uefi() {
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        print_error "Система не загружена в UEFI режиме!"
        if [[ $BOOTLOADER == "systemd-boot" ]]; then
            print_warning "systemd-boot требует UEFI. Переключаю на GRUB."
            BOOTLOADER="grub"
        fi
    else
        print_success "UEFI режим обнаружен"
    fi
}

# Выбор диска
select_disk() {
    print_info "Доступные диски:"
    lsblk -d -o NAME,SIZE,MODEL
    echo
    read -p "Введите имя диска для установки (например: sda, nvme0n1): " DISK
    DISK_PATH="/dev/$DISK"
    
    if [[ ! -b $DISK_PATH ]]; then
        print_error "Диск $DISK_PATH не найден!"
        exit 1
    fi
}

# Разметка диска
partition_disk() {
    print_info "Разметка диска $DISK_PATH..."
    
    # Очистка таблицы разделов
    sgdisk -Z $DISK_PATH
    
    # Создание разделов
    # EFI раздел (500M)
    sgdisk -n 1:0:+500M -t 1:ef00 $DISK_PATH
    # Root раздел (оставшееся место)
    sgdisk -n 2:0:0 -t 2:8300 $DISK_PATH
    
    # Swap раздел (опционально)
    read -p "Создать swap раздел? (y/N): " create_swap
    if [[ $create_swap == "y" || $create_swap == "Y" ]]; then
        sgdisk -n 3:0:+4G -t 3:8200 $DISK_PATH
        HAS_SWAP=true
    fi
    
    # Обновление информации о разделах
    partprobe $DISK_PATH
    sleep 2
}

# Форматирование разделов
format_partitions() {
    print_info "Форматирование разделов..."
    
    # EFI раздел
    EFI_PART="${DISK_PATH}1"
    mkfs.fat -F32 $EFI_PART
    
    # Root раздел
    ROOT_PART="${DISK_PATH}2"
    mkfs.ext4 $ROOT_PART
    
    # Swap раздел
    if [[ $HAS_SWAP == true ]]; then
        SWAP_PART="${DISK_PATH}3"
        mkswap $SWAP_PART
        swapon $SWAP_PART
    fi
    
    print_success "Разделы отформатированы"
}

# Монтирование разделов
mount_partitions() {
    print_info "Монтирование разделов..."
    
    mount $ROOT_PART /mnt
    mkdir -p /mnt/boot
    mount $EFI_PART /mnt/boot
    
    print_success "Разделы смонтированы"
}

# Установка базовой системы
install_base() {
    print_info "Установка базовой системы..."
    
    local base_packages="base base-devel linux linux-firmware linux-headers efibootmgr sudo networkmanager nano git"
    
    if [[ $BOOTLOADER == "grub" ]]; then
        base_packages="$base_packages grub efibootmgr"
    fi
    
    pacstrap /mnt $base_packages
    
    print_success "Базовая система установлена"
}

# Генерация fstab
generate_fstab() {
    genfstab -U /mnt >> /mnt/fstab
    print_success "fstab сгенерирован"
}

# Настройка systemd-boot
setup_systemd_boot() {
    arch-chroot /mnt /bin/bash <<EOF
bootctl install

# Конфигурация загрузчика
cat > /boot/loader/loader.conf << LOADER_EOF
default arch.conf
timeout 3
console-mode keep
editor no
LOADER_EOF

# Получение PARTUUID root раздела
ROOT_PARTUUID=\$(blkid -s PARTUUID -o value $ROOT_PART)

# Создание записи загрузки
cat > /boot/loader/entries/arch.conf << ENTRY_EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTUUID=\$ROOT_PARTUUID rw quiet
ENTRY_EOF

# Резервная запись
cat > /boot/loader/entries/arch-fallback.conf << FALLBACK_EOF
title Arch Linux (fallback)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options root=PARTUUID=\$ROOT_PARTUUID rw
FALLBACK_EOF
EOF
}

# Настройка GRUB
setup_grub() {
    arch-chroot /mnt /bin/bash <<EOF
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF
}

# Настройка системы в chroot
configure_system() {
    print_info "Настройка системы..."
    
    arch-chroot /mnt /bin/bash <<EOF
set -e

# Настройка времени
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Локализация
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LANGUAGE" > /etc/locale.conf

# Настройка хоста
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << HOSTS_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS_EOF

# Пароль root
echo "root:$root_password" | chpasswd

# Создание пользователя
useradd -m -G wheel -s /bin/bash $USERNAME
echo "$USERNAME:$user_password" | chpasswd

# Настройка sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Установка загрузчика
if [[ "$BOOTLOADER" == "systemd-boot" ]]; then
    setup_systemd_boot
else
    setup_grub
fi

# Установка графической оболочки
if [[ "$DE" != "none" ]]; then
    pacman -S --noconfirm xorg xorg-server $DE_PACKAGES
    systemctl enable $DM_SERVICE
fi

# Установка дополнительных пакетов
if [[ -n "$ADDITIONAL_PACKAGES" ]]; then
    pacman -S --noconfirm $ADDITIONAL_PACKAGES
fi

# Генерация initramfs
mkinitcpio -P

# Включение NetworkManager
systemctl enable NetworkManager

print_success "Система настроена"
EOF
}

# Основная функция
main() {
    print_warning "ВНИМАНИЕ: Этот скрипт уничтожит все данные на выбранном диске!"
    read -p "Продолжить? (y/N): " confirm
    
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        print_info "Установка отменена"
        exit 0
    fi
    
    # Получение данных от пользователя
    get_user_input
    get_de_packages
    
    # Проверки
    check_uefi
    
    # Выбор и подготовка диска
    select_disk
    partition_disk
    format_partitions
    mount_partitions
    
    # Установка системы
    install_base
    generate_fstab
    configure_system
    
    # Завершение
    print_info "Завершение установки..."
    umount -R /mnt
    
    print_success "Установка завершена!"
    echo
    print_info "=== ДАННЫЕ ДЛЯ ВХОДА ==="
    print_info "Имя компьютера: $HOSTNAME"
    print_info "Пользователь: $USERNAME"
    print_info "Пароль пользователя: (установленный вами)"
    print_info "Пароль root: (установленный вами)"
    echo
    print_info "Выполните: reboot"
    print_info "После перезагрузки войдите как: $USERNAME"
    
    if [[ $DE != "none" ]]; then
        print_info "Графический интерфейс: $DE"
    fi
}

# Запуск скрипта
if [[ $EUID -eq 0 ]]; then
    main
else
    print_error "Этот скрипт должен запускаться от root!"
    exit 1
fi
