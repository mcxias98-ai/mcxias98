#!/bin/bash

# Цвета для оформления
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для отрисовки прогресс-бара
progress_bar() {
    local duration=${1}
    local columns=$(tput cols)
    local space=$(( columns - 10 ))
    already_done() { for ((done=0; done<$1; done++)); do printf "▇"; done }
    remaining() { for ((remain=$1; remain<$space; remain++)); do printf " "; done }
    percentage() { printf "| %s%%" $(( (($1)*100)/($space)*100/100 )); }
    sleep_and_done() { 
        sleep ${duration}
        already_done $space
        remaining $space
        percentage $space
        printf "\n";
    }
    
    sleep_and_done &
    while kill -0 $! 2>/dev/null; do
        already_done $(( (($space)*$SECONDS)/$duration ))
        remaining $(( (($space)*$SECONDS)/$duration ))
        percentage $(( (($space)*$SECONDS)/$duration ))
        sleep 0.1
        printf "\r"
    done
    printf "\n"
}

# Красивый вывод заголовков
print_header() {
    echo -e "${PURPLE}"
    echo "=========================================="
    echo "    $1"
    echo "=========================================="
    echo -e "${NC}"
}

# Красивый вывод информации
print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

# Красивый вывод успеха
print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Красивое предупреждение
print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Красивое сообщение об ошибке
print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Установка русского шрифта для консоли
set_russian_font() {
    print_info "Установка русского шрифта для консоли..."
    setfont cyr-sun16
    print_success "Шрифт установлен"
}

# Проверка на UEFI
check_uefi() {
    print_info "Проверка типа firmware..."
    if [ -d /sys/firmware/efi ]; then
        UEFI=true
        print_success "Обнаружена UEFI система"
    else
        UEFI=false
        print_success "Обнаружена BIOS система"
    fi
}

# Функция для выбора графической оболочки
select_desktop() {
    echo -e "${BLUE}"
    echo "Выберите графическую оболочку:"
    echo -e "${GREEN}1) GNOME${NC}"
    echo -e "${GREEN}2) KDE Plasma${NC}"
    echo -e "${GREEN}3) XFCE${NC}"
    echo -e "${GREEN}4) LXDE${NC}"
    echo -e "${GREEN}5) Cinnamon${NC}"
    echo -e "${GREEN}6) Только базовая система (без DE)${NC}"
    echo -ne "${YELLOW}Ваш выбор [1-6]: ${NC}"
    read -r de_choice
    
    case $de_choice in
        1) DESKTOP_ENV="gnome";;
        2) DESKTOP_ENV="plasma";;
        3) DESKTOP_ENV="xfce";;
        4) DESKTOP_ENV="lxde";;
        5) DESKTOP_ENV="cinnamon";;
        6) DESKTOP_ENV="none";;
        *) 
            print_warning "Неверный выбор, используется GNOME"
            DESKTOP_ENV="gnome"
            ;;
    esac
    
    print_success "Выбрано: $DESKTOP_ENV"
}

# Функция для выбора типа загрузки
select_boot_type() {
    echo -e "${BLUE}"
    echo "Выберите тип загрузки:"
    echo -e "${GREEN}1) Обычная загрузка${NC}"
    echo -e "${GREEN}2) Тихая загрузка (без сообщений)${NC}"
    echo -ne "${YELLOW}Ваш выбор [1-2]: ${NC}"
    read -r boot_choice
    
    case $boot_choice in
        1) QUIET_BOOT=false;;
        2) QUIET_BOOT=true;;
        *) 
            print_warning "Неверный выбор, используется обычная загрузка"
            QUIET_BOOT=false
            ;;
    esac
}

# Функция для выбора дополнительных пакетов
select_additional_packages() {
    echo -e "${BLUE}"
    echo "Выберите дополнительные пакеты (можно выбрать несколько через запятую):"
    echo -e "${GREEN}1) Офисные приложения (libreoffice)${NC}"
    echo -e "${GREEN}2) Мультимедиа (vlc, gstreamer)${NC}"
    echo -e "${GREEN}3) Графика (gimp, inkscape)${NC}"
    echo -e "${GREEN}4) Браузеры (firefox, chromium)${NC}"
    echo -e "${GREEN}5) Разработка (code, git, python)${NC}"
    echo -e "${GREEN}6) Игры (steam)${NC}"
    echo -e "${GREEN}7) Проприетарные драйверы NVIDIA${NC}"
    echo -e "${GREEN}8) Все вышеперечисленное${NC}"
    echo -e "${GREEN}9) Пропустить${NC}"
    echo -ne "${YELLOW}Ваш выбор: ${NC}"
    read -r packages_choice
    
    ADDITIONAL_PACKAGES=""
    IFS=',' read -ra choices <<< "$packages_choice"
    
    for choice in "${choices[@]}"; do
        case $choice in
            1) ADDITIONAL_PACKAGES+=" libreoffice libreoffice-fresh-ru ";;
            2) ADDITIONAL_PACKAGES+=" vlc gstreamer ";;
            3) ADDITIONAL_PACKAGES+=" gimp inkscape ";;
            4) ADDITIONAL_PACKAGES+=" firefox chromium ";;
            5) ADDITIONAL_PACKAGES+=" code git python konsole ";;
            6) ADDITIONAL_PACKAGES+=" steam ";;
            7) ADDITIONAL_PACKAGES+=" nvidia nvidia-utils ";;
            8) ADDITIONAL_PACKAGES+=" libreoffice libreoffice-fresh-ru vlc gstreamer gimp inkscape firefox chromium code git python steam nvidia nvidia-utils ";;
            9) ;;
            *) print_warning "Неверный выбор: $choice";;
        esac
    done
}

# Функция для выбора диска
select_disk() {
    print_info "Доступные диски:"
    lsblk
    echo -ne "${YELLOW}Введите имя диска для установки (например, sda, nvme0n1): ${NC}"
    read -r DISK
    DISK_PATH="/dev/$DISK"
    print_success "Выбран диск: $DISK_PATH"
}

# Функция для разметки диска
partition_disk() {
    print_info "Разметка диска $DISK_PATH..."
    
    if [ "$UEFI" = true ]; then
        # UEFI разметка
        parted -s "$DISK_PATH" mklabel gpt
        parted -s "$DISK_PATH" mkpart primary fat32 1MiB 513MiB
        parted -s "$DISK_PATH" set 1 esp on
        parted -s "$DISK_PATH" mkpart primary ext4 513MiB 100%
    else
        # BIOS разметка
        parted -s "$DISK_PATH" mklabel msdos
        parted -s "$DISK_PATH" mkpart primary ext4 1MiB 100%
        parted -s "$DISK_PATH" set 1 boot on
    fi
    
    partprobe "$DISK_PATH"
    print_success "Разметка завершена"
}

# Функция для форматирования разделов
format_partitions() {
    print_info "Форматирование разделов..."
    
    if [ "$UEFI" = true ]; then
        mkfs.fat -F32 "${DISK_PATH}1"
        mkfs.ext4 "${DISK_PATH}2"
    else
        mkfs.ext4 "${DISK_PATH}1"
    fi
    
    print_success "Форматирование завершено"
}

# Функция для монтирования разделов
mount_partitions() {
    print_info "Монтирование разделов..."
    
    mount "${DISK_PATH}2" /mnt
    
    if [ "$UEFI" = true ]; then
        mkdir -p /mnt/boot/efi
        mount "${DISK_PATH}1" /mnt/boot/efi
    fi
    
    print_success "Монтирование завершено"
}

# Функция для установки базовой системы
install_base_system() {
    print_info "Установка базовой системы..."
    if pacstrap /mnt base base-devel linux linux-firmware; then
        print_success "Базовая система установлена"
    else
        print_error "Ошибка установки базовой системы"
        exit 1
    fi
}

# Функция для настройки системы
configure_system() {
    # Генерация fstab
    print_info "Генерация fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
    
    # Создаем скрипт для настройки внутри chroot
    cat > /mnt/root/chroot_setup.sh << 'EOF'
#!/bin/bash

# Цвета для оформления
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для красивого вывода
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Установка русского шрифта в устанавливаемой системе
print_info "Установка русского шрифта..."
pacman -S --noconfirm terminus-font

# Настройка времени
print_info "Настройка времени..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Локализация
print_info "Настройка локализации..."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Устанавливаем русскую локаль по умолчанию
print_info "Установка русской локали..."
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
echo "LC_TIME=ru_RU.UTF-8" >> /etc/locale.conf

# Настройка клавиатуры
print_info "Настройка клавиатуры..."
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

# Настройка сети
print_info "Настройка сети..."
read -p "Введите имя компьютера: " hostname
echo "$hostname" > /etc/hostname

cat > /etc/hosts << HOSTS_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
HOSTS_EOF

# Установка загрузчика
print_info "Установка загрузчика..."
if [ "$UEFI" = true ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc $DISK_PATH
fi

# КРИТИЧЕСКИ ВАЖНО: Настройка GRUB для правильного отображения меню
print_info "Настройка GRUB..."
# Резервное копирование оригинального файла
cp /etc/default/grub /etc/default/grub.backup

# Базовые настройки GRUB
cat > /etc/default/grub << GRUB_EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TERMINAL_INPUT=console
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_RECOVERY=true
GRUB_EOF

# Добавляем параметры для тихой загрузки если выбрано
if [ "$QUIET_BOOT" = true ]; then
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3"/' /etc/default/grub
fi

# Обновляем конфиг GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Проверяем что меню GRUB создано
if [ -f /boot/grub/grub.cfg ]; then
    print_success "GRUB настроен успешно"
else
    print_error "Ошибка настройки GRUB!"
    exit 1
fi

# Установка графической оболочки и дополнительных пакетов
print_info "Установка графической оболочки..."
case "$DESKTOP_ENV" in
    "gnome")
        pacman -S --noconfirm gnome gnome-extra gdm
        systemctl enable gdm
        ;;
    "plasma")
        pacman -S --noconfirm plasma-meta plasma-wayland-session sddm
        systemctl enable sddm
        ;;
    "xfce")
        pacman -S --noconfirm xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
    "lxde")
        pacman -S --noconfirm lxde lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
    "cinnamon")
        pacman -S --noconfirm cinnamon lightdm lightdm-gtk-greeter
        systemctl enable lightdm
        ;;
    "none")
        print_info "Графическая оболочка не установлена"
        ;;
esac

# Дополнительные пакеты
if [ -n "$ADDITIONAL_PACKAGES" ]; then
    print_info "Установка дополнительных пакетов..."
    pacman -S --noconfirm $ADDITIONAL_PACKAGES
fi

# Включение служб
print_info "Настройка служб..."
systemctl enable NetworkManager

# Настройка пользователя
print_info "Настройка пользователя..."
read -p "Введите имя пользователя: " username
useradd -m -G wheel -s /bin/bash $username
echo "Установите пароль для пользователя $username:"
passwd $username

# Настройка sudo
print_info "Настройка sudo..."
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

# Установка пароля root
print_info "Установка пароля root..."
echo "Установите пароль root:"
passwd

# Создание файла xinitrc для пользователя
if [ "$DESKTOP_ENV" != "none" ]; then
    print_info "Создание xinitrc..."
    case "$DESKTOP_ENV" in
        "gnome") START_CMD="exec gnome-session";;
        "plasma") START_CMD="exec startplasma-x11";;
        "xfce") START_CMD="exec startxfce4";;
        "lxde") START_CMD="exec startlxde";;
        "cinnamon") START_CMD="exec cinnamon-session";;
    esac
    
    cat > /home/$username/.xinitrc << XINIT_EOF
#!/bin/bash
$START_CMD
XINIT_EOF
    chown $username:$username /home/$username/.xinitrc
    chmod +x /home/$username/.xinitrc
fi

# Создание приветственного файла с инструкциями по GRUB
cat > /home/$username/README_GRUB.txt << README_EOF
Инструкция по настройке GRUB:

Если у вас возникли проблемы с отображением меню GRUB:

1. Проверьте настройки в /etc/default/grub
2. Обновите конфигурацию GRUB:
   sudo grub-mkconfig -o /boot/grub/grub.cfg
3. Для UEFI систем проверьте наличие файлов в /boot/efi

Тихая загрузка: $QUIET_BOOT
Графическая оболочка: $DESKTOP_ENV
README_EOF

chown $username:$username /home/$username/README_GRUB.txt

print_success "Настройка системы завершена!"
EOF

    # Делаем скрипт исполняемым и запускаем в chroot
    chmod +x /mnt/root/chroot_setup.sh
    print_info "Запуск настройки внутри chroot..."
    arch-chroot /mnt /bin/bash -c "UEFI=$UEFI DISK_PATH=$DISK_PATH QUIET_BOOT=$QUIET_BOOT DESKTOP_ENV=$DESKTOP_ENV ADDITIONAL_PACKAGES=\"$ADDITIONAL_PACKAGES\" /root/chroot_setup.sh"
    
    # Удаляем временный скрипт
    rm /mnt/root/chroot_setup.sh
}

# Обновление ключей
update_keys() {
    print_info "Обновление ключей..."
    pacman -Sy --noconfirm archlinux-keyring
    pacman-key --init
    pacman-key --populate archlinux
    print_success "Ключи обновлены"
}

# Основная функция
main() {
    clear
    print_header "Arch Linux Installer"
    print_info "Начинается установка Arch Linux..."
    
    # Проверка интернета
    if ! ping -c 1 archlinux.org &> /dev/null; then
        print_error "Нет подключения к интернету!"
        exit 1
    fi
    
    # Запрос переменных у пользователя
    set_russian_font
    check_uefi
    select_desktop
    select_boot_type
    select_additional_packages
    select_disk
    
    # Подтверждение
    echo -e "${YELLOW}"
    echo "=== ПОДТВЕРЖДЕНИЕ УСТАНОВКИ ==="
    echo "Диск: $DISK_PATH"
    echo "UEFI: $UEFI"
    echo "Графическая оболочка: $DESKTOP_ENV"
    echo "Тихая загрузка: $QUIET_BOOT"
    echo "Дополнительные пакеты: $ADDITIONAL_PACKAGES"
    echo -e "${NC}"
    
    read -rp "Продолжить установку? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_error "Установка отменена."
        exit 0
    fi
    
    # Процесс установки
    print_header "НАЧАЛО УСТАНОВКИ"
    update_keys
    partition_disk
    format_partitions
    mount_partitions
    install_base_system
    configure_system
    
    # Завершение
    umount -R /mnt
    print_header "УСТАНОВКА ЗАВЕРШЕНА"
    print_success "Установка завершена успешно! Перезагрузите систему."
    echo -e "${YELLOW}Не забудьте извлечить установочный носитель!${NC}"
}

# Запуск основной функции
main "$@"
