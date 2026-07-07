#!/bin/bash

# ============================================================
# Arch Linux Interactive Installer (с поддержкой русского языка)
# ============================================================

# Установка локали для правильного отображения русского языка
export LANG=ru_RU.UTF-8
export LANGUAGE=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8

# Проверка и установка локали, если её нет
if ! locale -a | grep -q ru_RU.utf8; then
    echo "Установка русской локали..."
    locale-gen ru_RU.UTF-8 &>/dev/null || true
fi

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для красивого вывода
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}▶ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ Ошибка: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_menu() {
    echo -e "${CYAN}$1${NC}"
}

get_choice() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        result=${result:-$default}
    else
        read -p "$prompt: " result
    fi
    echo "$result"
}

get_yes_no() {
    local prompt="$1"
    local default="$2"
    local result
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt [Y/n]: " result
            result=${result:-y}
        elif [ "$default" = "n" ]; then
            read -p "$prompt [y/N]: " result
            result=${result:-n}
        else
            read -p "$prompt [y/n]: " result
        fi
        
        case "$result" in
            y|Y|yes|Yes|YES) return 0 ;;
            n|N|no|No|NO) return 1 ;;
            *) echo "Пожалуйста, введите y или n" ;;
        esac
    done
}

show_progress() {
    local msg="$1"
    echo -ne "${YELLOW}$msg... ${NC}"
    sleep 1
    echo -e "${GREEN}Готово${NC}"
}

# ============================================================
# НАЧАЛО УСТАНОВКИ
# ============================================================

clear

print_header "🖥️  ARCH LINUX INTERACTIVE INSTALLER"
echo -e "${CYAN}Данный скрипт поможет вам установить Arch Linux${NC}"
echo -e "${YELLOW}Внимание: Скрипт запускается от root!${NC}\n"

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
    print_error "Запустите скрипт от root: sudo bash $0"
    exit 1
fi

# Проверка интернета
print_step "Проверка подключения к интернету..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    print_error "Нет подключения к интернету!"
    echo -e "${YELLOW}Для Wi-Fi выполните:${NC}"
    echo "  iwctl"
    echo "  station wlan0 connect 'SSID'"
    echo "  exit"
    exit 1
fi
print_success "Интернет подключен"

# ============================================================
# 1. ВЫБОР ДИСКА
# ============================================================

print_header "💾 ВЫБОР ДИСКА"

echo -e "${CYAN}Доступные диски:${NC}"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "disk|part" | nl

echo ""
DISK=$(get_choice "Введите имя диска (например: sda, nvme0n1)" "")
DISK_PATH="/dev/$DISK"

if [ ! -b "$DISK_PATH" ]; then
    print_error "Диск $DISK_PATH не найден!"
    exit 1
fi

print_success "Выбран диск: $DISK_PATH"

# ============================================================
# 2. РАЗМЕТКА ДИСКА
# ============================================================

print_header "📊 РАЗМЕТКА ДИСКА"

echo -e "${YELLOW}Выберите схему разметки:${NC}"
echo "  1) Простая (EFI + корневой раздел)"
echo "  2) С отдельным /home (EFI + / + /home)"
echo "  3) Ручная разметка (cfdisk)"

PART_SCHEME=$(get_choice "Выберите вариант [1-3]" "1")

case $PART_SCHEME in
    1)
        print_info "Создаем разделы: EFI (512M) + / (всё остальное)"
        
        # Удаляем старые разделы
        dd if=/dev/zero of="$DISK_PATH" bs=512 count=1 conv=notrunc &>/dev/null
        
        # Создаем GPT разметку
        parted -s "$DISK_PATH" mklabel gpt
        
        # EFI раздел (512M)
        parted -s "$DISK_PATH" mkpart primary fat32 1MiB 513MiB
        parted -s "$DISK_PATH" set 1 esp on
        
        # Корневой раздел (всё остальное)
        parted -s "$DISK_PATH" mkpart primary ext4 513MiB 100%
        
        # Определяем имена разделов
        if [[ "$DISK" == nvme* ]]; then
            EFI_PART="${DISK_PATH}p1"
            ROOT_PART="${DISK_PATH}p2"
        else
            EFI_PART="${DISK_PATH}1"
            ROOT_PART="${DISK_PATH}2"
        fi
        
        print_success "Разделы созданы:"
        echo "  EFI: $EFI_PART (512M)"
        echo "  /:   $ROOT_PART"
        ;;
        
    2)
        print_info "Создаем разделы: EFI (512M) + / (30G) + /home (остальное)"
        
        # Удаляем старые разделы
        dd if=/dev/zero of="$DISK_PATH" bs=512 count=1 conv=notrunc &>/dev/null
        
        # Создаем GPT разметку
        parted -s "$DISK_PATH" mklabel gpt
        
        # EFI раздел (512M)
        parted -s "$DISK_PATH" mkpart primary fat32 1MiB 513MiB
        parted -s "$DISK_PATH" set 1 esp on
        
        # Корневой раздел (30G)
        parted -s "$DISK_PATH" mkpart primary ext4 513MiB 30.5GiB
        
        # /home раздел (всё остальное)
        parted -s "$DISK_PATH" mkpart primary ext4 30.5GiB 100%
        
        if [[ "$DISK" == nvme* ]]; then
            EFI_PART="${DISK_PATH}p1"
            ROOT_PART="${DISK_PATH}p2"
            HOME_PART="${DISK_PATH}p3"
        else
            EFI_PART="${DISK_PATH}1"
            ROOT_PART="${DISK_PATH}2"
            HOME_PART="${DISK_PATH}3"
        fi
        
        print_success "Разделы созданы:"
        echo "  EFI:  $EFI_PART (512M)"
        echo "  /:    $ROOT_PART (30G)"
        echo "  /home: $HOME_PART"
        ;;
        
    3)
        print_info "Запускаем ручную разметку через cfdisk"
        cfdisk "$DISK_PATH"
        
        echo -e "\n${CYAN}Введите имена созданных разделов:${NC}"
        EFI_PART=$(get_choice "EFI раздел (например: ${DISK}1)" "")
        ROOT_PART=$(get_choice "Корневой раздел (например: ${DISK}2)" "")
        
        if get_yes_no "Есть отдельный раздел для /home?" "n"; then
            HOME_PART=$(get_choice "Раздел /home (например: ${DISK}3)" "")
            HAS_HOME=true
        else
            HAS_HOME=false
        fi
        ;;
esac

# ============================================================
# 3. ФОРМАТИРОВАНИЕ
# ============================================================

print_header "🔧 ФОРМАТИРОВАНИЕ РАЗДЕЛОВ"

print_step "Форматирование EFI раздела ($EFI_PART)"
mkfs.vfat -F32 "$EFI_PART" &>/dev/null
print_success "EFI раздел отформатирован"

print_step "Форматирование корневого раздела ($ROOT_PART)"
mkfs.ext4 -F "$ROOT_PART" &>/dev/null
print_success "Корневой раздел отформатирован"

if [ -n "$HOME_PART" ]; then
    print_step "Форматирование раздела /home ($HOME_PART)"
    mkfs.ext4 -F "$HOME_PART" &>/dev/null
    print_success "Раздел /home отформатирован"
fi

# ============================================================
# 4. МОНТИРОВАНИЕ
# ============================================================

print_header "📂 МОНТИРОВАНИЕ РАЗДЕЛОВ"

print_step "Монтирование корневого раздела"
mount "$ROOT_PART" /mnt
print_success "Корневой раздел примонтирован в /mnt"

print_step "Монтирование EFI раздела"
mkdir -p /mnt/boot/efi
mount "$EFI_PART" /mnt/boot/efi
print_success "EFI раздел примонтирован в /mnt/boot/efi"

if [ -n "$HOME_PART" ]; then
    print_step "Монтирование раздела /home"
    mkdir -p /mnt/home
    mount "$HOME_PART" /mnt/home
    print_success "Раздел /home примонтирован в /mnt/home"
fi

# ============================================================
# 5. ВЫБОР ПАКЕТОВ
# ============================================================

print_header "📦 ВЫБОР ПАКЕТОВ"

# Базовые пакеты
BASE_PKGS="base base-devel linux linux-firmware linux-headers nano vim bash-completion grub efibootmgr networkmanager"

print_info "Базовые пакеты будут установлены автоматически:"
echo "  $BASE_PKGS"

# Дисплейный сервер
if get_yes_no "Установить Xorg (дисплейный сервер)?" "y"; then
    EXTRA_PKGS="$EXTRA_PKGS xorg"
fi

# Драйвера для видео
echo -e "\n${CYAN}Выберите видеодрайвер:${NC}"
echo "  1) Intel"
echo "  2) NVIDIA"
echo "  3) AMD/ATI"
echo "  4) VirtualBox (VM)"
echo "  5) Универсальный (без драйвера)"
VIDEO_DRIVER=$(get_choice "Выберите вариант [1-5]" "5")

case $VIDEO_DRIVER in
    1) EXTRA_PKGS="$EXTRA_PKGS xf86-video-intel" ;;
    2) EXTRA_PKGS="$EXTRA_PKGS nvidia nvidia-utils" ;;
    3) EXTRA_PKGS="$EXTRA_PKGS xf86-video-amdgpu" ;;
    4) EXTRA_PKGS="$EXTRA_PKGS virtualbox-guest-utils" ;;
    *) print_info "Универсальный драйвер (используется встроенный)" ;;
esac

# Шрифты
if get_yes_no "Установить дополнительные шрифты?" "y"; then
    EXTRA_PKGS="$EXTRA_PKGS ttf-ubuntu-font-family ttf-hack ttf-dejavu ttf-opensans ttf-liberation"
fi

# Дисплейный менеджер
echo -e "\n${CYAN}Выберите дисплейный менеджер:${NC}"
echo "  1) SDDM (рекомендуется для KDE)"
echo "  2) GDM (рекомендуется для GNOME)"
echo "  3) LightDM (легкий и настраиваемый)"
echo "  4) LXDM"
echo "  5) Не устанавливать"
DM_CHOICE=$(get_choice "Выберите вариант [1-5]" "1")

case $DM_CHOICE in
    1) EXTRA_PKGS="$EXTRA_PKGS sddm" ; DM_NAME="sddm" ;;
    2) EXTRA_PKGS="$EXTRA_PKGS gdm" ; DM_NAME="gdm" ;;
    3) EXTRA_PKGS="$EXTRA_PKGS lightdm lightdm-gtk-greeter" ; DM_NAME="lightdm" ;;
    4) EXTRA_PKGS="$EXTRA_PKGS lxdm" ; DM_NAME="lxdm" ;;
    *) print_info "Дисплейный менеджер не будет установлен" ;;
esac

# Окружение рабочего стола
echo -e "\n${CYAN}Выберите окружение рабочего стола:${NC}"
echo "  1) GNOME"
echo "  2) KDE Plasma"
echo "  3) Cinnamon"
echo "  4) Budgie"
echo "  5) XFCE4 (легкое)"
echo "  6) LXQt (легкое)"
echo "  7) LXDE (очень легкое)"
echo "  8) i3 (оконный менеджер)"
echo "  9) Не устанавливать"
DE_CHOICE=$(get_choice "Выберите вариант [1-9]" "1")

case $DE_CHOICE in
    1) EXTRA_PKGS="$EXTRA_PKGS gnome gnome-tweaks gnome-terminal" ; DE_NAME="gnome" ;;
    2) EXTRA_PKGS="$EXTRA_PKGS plasma konsole dolphin" ; DE_NAME="plasma" ;;
    3) EXTRA_PKGS="$EXTRA_PKGS cinnamon nemo" ; DE_NAME="cinnamon" ;;
    4) EXTRA_PKGS="$EXTRA_PKGS budgie budgie-desktop-view" ; DE_NAME="budgie" ;;
    5) EXTRA_PKGS="$EXTRA_PKGS xfce4 xfce4-goodies" ; DE_NAME="xfce4" ;;
    6) EXTRA_PKGS="$EXTRA_PKGS lxqt pcmanfm-qt" ; DE_NAME="lxqt" ;;
    7) EXTRA_PKGS="$EXTRA_PKGS lxde pcmanfm" ; DE_NAME="lxde" ;;
    8) EXTRA_PKGS="$EXTRA_PKGS i3-wm i3status i3lock dmenu" ; DE_NAME="i3" ;;
    *) print_info "Окружение рабочего стола не будет установлено" ;;
esac

# Звук
if get_yes_no "Установить звуковую систему (PulseAudio)?" "y"; then
    EXTRA_PKGS="$EXTRA_PKGS pulseaudio pulseaudio-alsa alsa-utils pavucontrol"
fi

# Дополнительные полезные пакеты
if get_yes_no "Установить дополнительные полезные пакеты?" "y"; then
    EXTRA_PKGS="$EXTRA_PKGS git wget curl htop neofetch firefox thunderbird libreoffice-fresh"
fi

# ============================================================
# 6. УСТАНОВКА СИСТЕМЫ
# ============================================================

print_header "⚡ УСТАНОВКА СИСТЕМЫ"

print_info "Устанавливаем базовую систему..."
pacstrap /mnt $BASE_PKGS

if [ -n "$EXTRA_PKGS" ]; then
    print_info "Устанавливаем дополнительные пакеты..."
    pacstrap /mnt $EXTRA_PKGS
fi

print_success "Система установлена"

# ============================================================
# 7. ГЕНЕРАЦИЯ FSTAB
# ============================================================

print_step "Генерация fstab"
genfstab -U /mnt >> /mnt/etc/fstab
print_success "fstab сгенерирован"

# ============================================================
# 8. НАСТРОЙКА В CHROOT (с поддержкой русского языка)
# ============================================================

print_header "⚙️  НАСТРОЙКА СИСТЕМЫ"

cat > /mnt/root/setup.sh << 'EOF'
#!/bin/bash

# Установка локалей для русского языка
echo "Настройка локалей..."
sed -i 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(ru_RU.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(ru_UA.UTF-8\)/\1/' /etc/locale.gen
locale-gen

# Настройка системной локали
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
echo "LANGUAGE=ru_RU.UTF-8" >> /etc/locale.conf
echo "LC_ALL=ru_RU.UTF-8" >> /etc/locale.conf

# Настройка клавиатуры
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

# Часовой пояс
echo "Настройка часового пояса..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Имя хоста
echo "Введите имя компьютера:"
read HOSTNAME
echo "$HOSTNAME" > /etc/hostname

# Настройка hosts
cat > /etc/hosts << HOSTS
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
HOSTS

# Пароль root
echo "Установка пароля root:"
passwd

# Создание пользователя
echo "Создание пользователя:"
read -p "Введите имя пользователя: " USERNAME
useradd -m -G wheel,audio,video,storage,optical "$USERNAME"
echo "Установка пароля для $USERNAME:"
passwd "$USERNAME"

# Настройка sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Включение NetworkManager
systemctl enable NetworkManager

EOF

chmod +x /mnt/root/setup.sh

print_step "Выполнение настройки в chroot..."
arch-chroot /mnt /root/setup.sh

# ============================================================
# 9. УСТАНОВКА ЗАГРУЗЧИКА
# ============================================================

print_header "🔄 УСТАНОВКА ЗАГРУЗЧИКА"

cat > /mnt/root/bootloader.sh << EOF
#!/bin/bash

# Установка GRUB
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

# Настройка GRUB (убираем quiet)
sed -i 's/quiet//g' /etc/default/grub

# Добавляем поддержку русского языка в GRUB
echo "GRUB_TERMINAL_INPUT=console" >> /etc/default/grub
echo "GRUB_TERMINAL_OUTPUT=console" >> /etc/default/grub

# Генерация конфига
grub-mkconfig -o /boot/grub/grub.cfg

# Включение дисплейного менеджера
if [ -n "$DM_NAME" ]; then
    systemctl enable $DM_NAME
fi

# Включение служб
systemctl enable NetworkManager

EOF

chmod +x /mnt/root/bootloader.sh
arch-chroot /mnt /root/bootloader.sh

# ============================================================
# 10. ЗАВЕРШЕНИЕ
# ============================================================

print_header "🎉 УСТАНОВКА ЗАВЕРШЕНА!"

print_success "Arch Linux успешно установлен!"

echo -e "${CYAN}Параметры установки:${NC}"
echo "  Диск: $DISK_PATH"
echo "  EFI раздел: $EFI_PART"
echo "  Корневой раздел: $ROOT_PART"
[ -n "$HOME_PART" ] && echo "  /home раздел: $HOME_PART"
[ -n "$DE_NAME" ] && echo "  Окружение: $DE_NAME"
[ -n "$DM_NAME" ] && echo "  Дисплейный менеджер: $DM_NAME"

echo -e "\n${YELLOW}Чтобы завершить установку и перезагрузиться:${NC}"
echo "  1. exit"
echo "  2. umount -R /mnt"
echo "  3. reboot"

echo -e "\n${GREEN}Не забудьте извлечь установочный носитель при перезагрузке!${NC}"

# Очистка
rm -f /mnt/root/setup.sh /mnt/root/bootloader.sh
