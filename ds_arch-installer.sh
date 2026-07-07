#!/bin/bash

# ============================================================
# Arch Linux Interactive Installer
# Полная поддержка русского языка
# Версия: 4.0
# ============================================================

# === НАСТРОЙКА РУССКОГО ЯЗЫКА ===

# Принудительная установка русской локали
export LANG=ru_RU.UTF-8
export LANGUAGE=ru_RU.UTF-8
export LC_ALL=ru_RU.UTF-8
export LC_CTYPE=ru_RU.UTF-8
export LC_NUMERIC=ru_RU.UTF-8
export LC_TIME=ru_RU.UTF-8
export LC_COLLATE=ru_RU.UTF-8
export LC_MONETARY=ru_RU.UTF-8
export LC_MESSAGES=ru_RU.UTF-8
export LC_PAPER=ru_RU.UTF-8
export LC_NAME=ru_RU.UTF-8
export LC_ADDRESS=ru_RU.UTF-8
export LC_TELEPHONE=ru_RU.UTF-8
export LC_MEASUREMENT=ru_RU.UTF-8
export LC_IDENTIFICATION=ru_RU.UTF-8

# Проверяем и устанавливаем локаль в системе
if ! locale -a 2>/dev/null | grep -q "ru_RU.utf8\|ru_RU.UTF-8"; then
    if [ -f /etc/locale.gen ]; then
        echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen 2>/dev/null
        locale-gen &>/dev/null || true
    fi
fi

# Убеждаемся, что терминал использует UTF-8
if [ -t 1 ]; then
    stty iutf8 2>/dev/null || true
fi

# === ЦВЕТА ДЛЯ ВЫВОДА ===

if [ -t 1 ] && [ "$TERM" != "dumb" ] && [ "$TERM" != "linux" ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''
    MAGENTA=''; CYAN=''; WHITE=''; BOLD=''; NC=''
fi

# === ФУНКЦИИ ВЫВОДА (БЕЗ ТРАНСЛИТЕРАЦИИ) ===

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "\n${GREEN}▶ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

print_warning() {
    echo -e "${MAGENTA}⚠ $1${NC}"
}

print_menu() {
    echo -e "${CYAN}$1${NC}"
}

# === ФУНКЦИИ ВВОДА ===

get_choice() {
    local prompt="$1"
    local default="$2"
    local result
    
    if [ -n "$default" ]; then
        echo -ne "${YELLOW}$prompt [$default]: ${NC}"
        read -r result
        result=${result:-$default}
    else
        echo -ne "${YELLOW}$prompt: ${NC}"
        read -r result
    fi
    echo "$result"
}

get_yes_no() {
    local prompt="$1"
    local default="$2"
    local result
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -ne "${YELLOW}$prompt [Y/n]: ${NC}"
            read -r result
            result=${result:-y}
        elif [ "$default" = "n" ]; then
            echo -ne "${YELLOW}$prompt [y/N]: ${NC}"
            read -r result
            result=${result:-n}
        else
            echo -ne "${YELLOW}$prompt [y/n]: ${NC}"
            read -r result
        fi
        
        case "$result" in
            y|Y|yes|Yes|YES|д|Д|да|Да|ДА) return 0 ;;
            n|N|no|No|NO|н|Н|нет|Нет|НЕТ) return 1 ;;
            *) echo -e "${RED}Пожалуйста, введите y или n${NC}" ;;
        esac
    done
}

# === НАСТРОЙКА WI-FI ===

setup_wifi() {
    print_header "НАСТРОЙКА WI-FI"
    
    # Проверяем, есть ли интернет
    if ping -c 1 archlinux.org &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
        print_success "Интернет уже подключен"
        if get_yes_no "Хотите настроить Wi-Fi заново?" "n"; then
            wifi_menu
        fi
        return 0
    fi
    
    wifi_menu
}

wifi_menu() {
    echo -e "${CYAN}Выберите способ подключения к Wi-Fi:${NC}"
    echo "  1) Через iwctl (рекомендуется)"
    echo "  2) Через nmtui (NetworkManager)"
    echo "  3) Ручной ввод команд"
    echo "  4) Пропустить (если есть Ethernet)"
    
    local choice=$(get_choice "Выберите вариант [1-4]" "1")
    
    case $choice in
        1) wifi_iwctl ;;
        2) wifi_nmtui ;;
        3) wifi_manual ;;
        4) print_info "Пропускаем настройку Wi-Fi" ;;
        *) print_error "Неверный выбор"; wifi_menu ;;
    esac
}

wifi_iwctl() {
    print_step "Настройка Wi-Fi через iwctl"
    
    # Проверяем iwd
    if ! systemctl is-active --quiet iwd 2>/dev/null; then
        print_info "Запуск службы iwd..."
        systemctl start iwd 2>/dev/null || {
            print_warning "Не удалось запустить iwd, пробуем через NetworkManager"
            wifi_nmtui
            return
        }
    fi
    
    # Получаем список устройств
    echo -e "${CYAN}Доступные Wi-Fi устройства:${NC}"
    iwctl device list 2>/dev/null || echo "Нет доступных устройств"
    echo ""
    
    local device=$(get_choice "Введите имя устройства (например: wlan0)" "wlan0")
    
    # Включаем устройство
    iwctl device "$device" set-property Powered on 2>/dev/null || true
    
    # Сканируем сети
    print_info "Сканирование сетей Wi-Fi (подождите 10 секунд)..."
    iwctl station "$device" scan 2>/dev/null || true
    sleep 10
    
    # Показываем сети
    echo -e "${CYAN}Доступные сети Wi-Fi:${NC}"
    iwctl station "$device" get-networks 2>/dev/null || echo "Нет доступных сетей"
    echo ""
    
    local ssid=$(get_choice "Введите SSID сети" "")
    
    if [ -z "$ssid" ]; then
        print_error "SSID не может быть пустым"
        wifi_iwctl
        return
    fi
    
    # Пытаемся подключиться
    print_info "Подключение к $ssid..."
    if iwctl station "$device" connect "$ssid" 2>/dev/null; then
        print_success "Подключено к $ssid"
        
        sleep 5
        if ping -c 1 archlinux.org &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
            print_success "Интернет работает"
            return 0
        else
            print_warning "Подключение установлено, но интернет не работает"
            if get_yes_no "Попробовать другой способ?" "y"; then
                wifi_menu
            fi
        fi
    else
        print_error "Не удалось подключиться к $ssid"
        if get_yes_no "Попробовать другой способ?" "y"; then
            wifi_menu
        fi
    fi
}

wifi_nmtui() {
    print_step "Настройка Wi-Fi через nmtui"
    
    if ! command -v nmtui &>/dev/null; then
        print_info "Установка NetworkManager..."
        pacman -S --noconfirm networkmanager 2>/dev/null || {
            print_error "Не удалось установить NetworkManager"
            return 1
        }
    fi
    
    systemctl start NetworkManager 2>/dev/null || {
        print_warning "Не удалось запустить NetworkManager"
        if get_yes_no "Попробовать через iwctl?" "y"; then
            wifi_iwctl
        fi
        return
    }
    
    print_info "Запуск nmtui..."
    nmtui
    
    if ping -c 1 archlinux.org &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
        print_success "Интернет работает"
        return 0
    else
        print_warning "Интернет не работает"
        if get_yes_no "Попробовать другой способ?" "y"; then
            wifi_menu
        fi
    fi
}

wifi_manual() {
    print_step "Ручная настройка Wi-Fi"
    
    echo -e "${YELLOW}Введите следующие команды:${NC}"
    echo "  iwctl"
    echo "  device list"
    echo "  station <device> scan"
    echo "  station <device> get-networks"
    echo "  station <device> connect 'SSID'"
    echo "  exit"
    echo ""
    echo -e "${CYAN}Или используйте:${NC}"
    echo "  nmcli device wifi list"
    echo "  nmcli device wifi connect 'SSID' password 'PASSWORD'"
    echo ""
    
    if get_yes_no "Хотите ввести команды вручную?" "y"; then
        echo -e "${YELLOW}Выход из оболочки - Ctrl+D или exit${NC}"
        bash
        
        if ping -c 1 archlinux.org &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
            print_success "Интернет работает"
            return 0
        else
            print_warning "Интернет не работает"
            if get_yes_no "Попробовать другой способ?" "y"; then
                wifi_menu
            fi
        fi
    else
        wifi_menu
    fi
}

# === ПРОВЕРКИ СИСТЕМЫ ===

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "Запустите скрипт от root: sudo bash $0"
        exit 1
    fi
}

check_internet() {
    print_step "Проверка подключения к интернету..."
    
    local tries=0
    local max_tries=10
    
    while [ $tries -lt $max_tries ]; do
        if ping -c 1 archlinux.org &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null; then
            print_success "Интернет подключен"
            return 0
        fi
        tries=$((tries + 1))
        echo -ne "${YELLOW}.${NC}"
        sleep 1
    done
    echo ""
    
    print_error "Нет подключения к интернету!"
    echo -e "${YELLOW}Попробуйте настроить Wi-Fi вручную:${NC}"
    echo "  1) iwctl"
    echo "  2) nmtui"
    echo "  3) nmcli"
    
    if get_yes_no "Хотите попробовать настроить Wi-Fi снова?" "y"; then
        wifi_menu
        check_internet
    else
        print_error "Установка невозможна без интернета"
        exit 1
    fi
}

check_uefi() {
    if [ -d /sys/firmware/efi ]; then
        print_success "Обнаружена UEFI система"
        return 0
    else
        print_warning "Обнаружена BIOS система (не UEFI)"
        if ! get_yes_no "Продолжить установку в режиме BIOS?" "n"; then
            exit 1
        fi
        return 1
    fi
}

check_disk_space() {
    local disk="$1"
    local size=$(blockdev --getsize64 "$disk" 2>/dev/null)
    local size_gb=$((size / 1024 / 1024 / 1024))
    
    if [ "$size_gb" -lt 20 ]; then
        print_warning "Размер диска $size_gb GB меньше рекомендуемых 20 GB"
        if ! get_yes_no "Продолжить установку?" "n"; then
            exit 1
        fi
    else
        print_info "Размер диска: $size_gb GB"
    fi
}

# === ОСНОВНЫЕ ФУНКЦИИ УСТАНОВКИ ===

select_disk() {
    print_header "ВЫБОР ДИСКА"
    
    echo -e "${CYAN}Доступные диски:${NC}"
    echo ""
    lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT | grep -E "disk|part" | nl -w2 -s'. '
    echo ""
    
    while true; do
        DISK=$(get_choice "Введите имя диска (например: sda, nvme0n1)" "")
        DISK_PATH="/dev/$DISK"
        
        if [ ! -b "$DISK_PATH" ]; then
            print_error "Диск $DISK_PATH не найден!"
            echo -e "${CYAN}Доступные диски:${NC}"
            lsblk -d -o NAME,SIZE,TYPE,MODEL | grep -v "loop"
            continue
        fi
        
        if mount | grep -q "$DISK_PATH"; then
            print_warning "Диск $DISK_PATH смонтирован!"
            if ! get_yes_no "Продолжить (данные могут быть повреждены)?" "n"; then
                continue
            fi
        fi
        
        check_disk_space "$DISK_PATH"
        print_success "Выбран диск: $DISK_PATH"
        break
    done
}

select_partition_scheme() {
    print_header "РАЗМЕТКА ДИСКА"
    
    echo -e "${YELLOW}Выберите схему разметки:${NC}"
    echo "  1) Простая (EFI + корневой раздел)"
    echo "  2) С отдельным /home (EFI + / + /home)"
    echo "  3) Ручная разметка (cfdisk)"
    
    PART_SCHEME=$(get_choice "Выберите вариант [1-3]" "1")
    
    case $PART_SCHEME in
        1)
            print_info "Создаем разделы: EFI (512M) + / (всё остальное)"
            
            dd if=/dev/zero of="$DISK_PATH" bs=512 count=1 conv=notrunc &>/dev/null
            parted -s "$DISK_PATH" mklabel gpt
            parted -s "$DISK_PATH" mkpart primary fat32 1MiB 513MiB
            parted -s "$DISK_PATH" set 1 esp on
            parted -s "$DISK_PATH" mkpart primary ext4 513MiB 100%
            
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
            
            dd if=/dev/zero of="$DISK_PATH" bs=512 count=1 conv=notrunc &>/dev/null
            parted -s "$DISK_PATH" mklabel gpt
            parted -s "$DISK_PATH" mkpart primary fat32 1MiB 513MiB
            parted -s "$DISK_PATH" set 1 esp on
            parted -s "$DISK_PATH" mkpart primary ext4 513MiB 30.5GiB
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
            fi
            ;;
    esac
}

format_partitions() {
    print_header "ФОРМАТИРОВАНИЕ РАЗДЕЛОВ"
    
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
}

mount_partitions() {
    print_header "МОНТИРОВАНИЕ РАЗДЕЛОВ"
    
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
}

select_packages() {
    print_header "ВЫБОР ПАКЕТОВ"
    
    BASE_PKGS="base base-devel linux linux-firmware linux-headers nano vim konsole bash-completion grub efibootmgr networkmanager"
    FONT_PKGS="ttf-ubuntu-font-family ttf-hack ttf-dejavu ttf-opensans"
    
    print_info "Базовые пакеты будут установлены автоматически:"
    echo "  $BASE_PKGS"
    echo "  $FONT_PKGS"
    
    if get_yes_no "Установить Xorg (дисплейный сервер)?" "y"; then
        EXTRA_PKGS="$EXTRA_PKGS xorg"
    fi
    
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
    
    if get_yes_no "Установить звуковую систему (PulseAudio)?" "y"; then
        EXTRA_PKGS="$EXTRA_PKGS pulseaudio pulseaudio-alsa alsa-utils pavucontrol"
    fi
    
    if get_yes_no "Установить дополнительные полезные пакеты?" "y"; then
        EXTRA_PKGS="$EXTRA_PKGS git wget curl htop neofetch firefox"
    fi
}

install_system() {
    print_header "УСТАНОВКА СИСТЕМЫ"
    
    print_info "Устанавливаем базовую систему с русскими шрифтами..."
    pacstrap /mnt $BASE_PKGS $FONT_PKGS
    
    if [ -n "$EXTRA_PKGS" ]; then
        print_info "Устанавливаем дополнительные пакеты..."
        pacstrap /mnt $EXTRA_PKGS
    fi
    
    print_success "Система установлена"
}

generate_fstab() {
    print_step "Генерация fstab"
    genfstab -U /mnt >> /mnt/etc/fstab
    print_success "fstab сгенерирован"
}

configure_system() {
    print_header "НАСТРОЙКА СИСТЕМЫ (С РУССКИМ ЯЗЫКОМ)"
    
    cat > /mnt/root/setup.sh << 'EOF'
#!/bin/bash

# === НАСТРОЙКА РУССКОГО ЯЗЫКА ===

echo "Настройка локалей..."
sed -i 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(ru_RU.UTF-8\)/\1/' /etc/locale.gen
locale-gen

echo "LANG=ru_RU.UTF-8" > /etc/locale.conf
echo "LANGUAGE=ru_RU.UTF-8" >> /etc/locale.conf
echo "LC_ALL=ru_RU.UTF-8" >> /etc/locale.conf

echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

echo "Настройка часового пояса..."
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

echo "Введите имя компьютера:"
read HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << HOSTS
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
HOSTS

echo "Установка пароля root:"
passwd

echo "Создание пользователя:"
read -p "Введите имя пользователя: " USERNAME
useradd -m -G wheel,audio,video,storage,optical "$USERNAME"
echo "Установка пароля для $USERNAME:"
passwd "$USERNAME"

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
systemctl enable NetworkManager

EOF
    
    chmod +x /mnt/root/setup.sh
    print_step "Выполнение настройки в chroot..."
    arch-chroot /mnt /root/setup.sh
}

install_bootloader() {
    print_header "УСТАНОВКА ЗАГРУЗЧИКА"
    
    cat > /mnt/root/bootloader.sh << EOF
#!/bin/bash

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

sed -i 's/quiet//g' /etc/default/grub

echo "GRUB_TERMINAL_INPUT=console" >> /etc/default/grub
echo "GRUB_TERMINAL_OUTPUT=console" >> /etc/default/grub
echo "GRUB_FONT=/usr/share/grub/unicode.pf2" >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

if [ -n "$DM_NAME" ]; then
    systemctl enable $DM_NAME
fi

systemctl enable NetworkManager

EOF
    
    chmod +x /mnt/root/bootloader.sh
    arch-chroot /mnt /root/bootloader.sh
}

# === ОСНОВНАЯ ФУНКЦИЯ ===

main() {
    clear
    
    print_header "ARCH LINUX INTERACTIVE INSTALLER"
    echo -e "${CYAN}Полная поддержка русского языка${NC}"
    echo -e "${YELLOW}Внимание: Скрипт запускается от root!${NC}\n"
    
    check_root
    
    setup_wifi
    
    check_internet
    
    check_uefi
    
    select_disk
    
    select_partition_scheme
    
    format_partitions
    
    mount_partitions
    
    select_packages
    
    install_system
    
    generate_fstab
    
    configure_system
    
    install_bootloader
    
    print_header "УСТАНОВКА ЗАВЕРШЕНА!"
    print_success "Arch Linux успешно установлен с поддержкой русского языка!"
    
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
    
    rm -f /mnt/root/setup.sh /mnt/root/bootloader.sh
}

main
