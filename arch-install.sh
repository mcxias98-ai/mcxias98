#!/bin/bash

# Установка русского шрифта для консоли
setfont cyr-sun16 2>/dev/null || echo "Русский шрифт не доступен, продолжаем..."

# Проверка на UEFI
if [ -d /sys/firmware/efi ]; then
    echo "Обнаружена UEFI система"
    UEFI_MODE=true
else
    echo "Обнаружена BIOS система"
    UEFI_MODE=false
fi

# Функция для выбора графической оболочки
select_desktop() {
    echo ""
    echo "Выберите графическую оболочку:"
    echo "1) KDE Plasma (полная среда)"
    echo "2) GNOME (современная среда)"
    echo "3) XFCE (легковесная среда)"
    echo "4) LXQt (очень легкая среда)"
    echo "5) Только базовый Xorg (без DE)"
    echo "6) Только консоль (без графики)"
    echo ""
    
    read -p "Введите номер варианта (1-6): " DE_CHOICE
    
    case $DE_CHOICE in
        1)
            DE_PACKAGES="plasma-meta konsole kate dolphin discover"
            DM_PACKAGE="sddm"
            DESKTOP_NAME="KDE Plasma"
            ;;
        2)
            DE_PACKAGES="gnome gnome-extra"
            DM_PACKAGE="gdm"
            DESKTOP_NAME="GNOME"
            ;;
        3)
            DE_PACKAGES="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"
            DM_PACKAGE="lightdm"
            DESKTOP_NAME="XFCE"
            ;;
        4)
            DE_PACKAGES="lxqt breeze-icons lightdm lightdm-gtk-greeter"
            DM_PACKAGE="lightdm"
            DESKTOP_NAME="LXQt"
            ;;
        5)
            DE_PACKAGES="xorg-server xorg-xinit"
            DM_PACKAGE=""
            DESKTOP_NAME="Xorg only"
            ;;
        6)
            DE_PACKAGES=""
            DM_PACKAGE=""
            DESKTOP_NAME="Console only"
            ;;
        *)
            echo "Неверный выбор, используется KDE Plasma по умолчанию"
            DE_PACKAGES="plasma-meta konsole kate dolphin discover"
            DM_PACKAGE="sddm"
            DESKTOP_NAME="KDE Plasma"
            ;;
    esac
    
    echo "Выбрана: $DESKTOP_NAME"
}

# Функция для выбора типа загрузки
select_boot_style() {
    echo ""
    echo "Выберите стиль загрузки:"
    echo "1) Тихая загрузка (без сообщений, только лого)"
    echo "2) Стандартная загрузка с сообщениями (рекомендуется для отладки)"
    echo ""
    
    read -p "Введите номер варианта (1-2): " BOOT_CHOICE
    
    case $BOOT_CHOICE in
        1)
            BOOT_STYLE="quiet"
            echo "Выбрана тихая загрузка"
            ;;
        2)
            BOOT_STYLE="verbose"
            echo "Выбрана стандартная загрузка с сообщениями"
            ;;
        *)
            BOOT_STYLE="verbose"
            echo "Неверный выбор, используется стандартная загрузка"
            ;;
    esac
}

# Функция для выбора дополнительных пакетов
select_additional_packages() {
    echo ""
    echo "Дополнительные пакеты:"
    echo "Базовые: networkmanager sudo nano vim git openssh"
    
    if [ -n "$DE_PACKAGES" ] && [ "$DE_PACKAGES" != "xorg-server xorg-xinit" ]; then
        read -p "Установить дополнительные офисные приложения? (y/N): " OFFICE
        read -p "Установить мультимедиа приложения? (y/N): " MEDIA
        read -p "Установить системные утилиты? (y/N): " UTILS
    fi
    
    ADDITIONAL_PACKAGES="networkmanager sudo nano vim git openssh"
    
    if [ "$OFFICE" = "y" ] || [ "$OFFICE" = "Y" ]; then
        ADDITIONAL_PACKAGES+=" libreoffice-fresh-ru"
    fi
    
    if [ "$MEDIA" = "y" ] || [ "$MEDIA" = "Y" ]; then
        ADDITIONAL_PACKAGES+=" vlc firefox firefox-i18n-ru"
    fi
    
    if [ "$UTILS" = "y" ] || [ "$UTILS" = "Y" ]; then
        ADDITIONAL_PACKAGES+=" htop neofetch curl wget"
    fi
}

# Функция для выбора диска
select_disk() {
    echo "Доступные диски:"
    lsblk -d -o NAME,SIZE,MODEL
    echo ""
    read -p "Введите имя диска для установки (например: sda, nvme0n1): " DISK
    DISK_PATH="/dev/$DISK"
}

# Функция для разметки диска
partition_disk() {
    echo "Разметка диска $DISK_PATH..."
    
    if [ "$UEFI_MODE" = true ]; then
        # UEFI разметка
        parted -s $DISK_PATH mklabel gpt
        parted -s $DISK_PATH mkpart primary fat32 1MiB 513MiB
        parted -s $DISK_PATH set 1 esp on
        parted -s $DISK_PATH mkpart primary ext4 513MiB 100%
    else
        # BIOS разметка
        parted -s $DISK_PATH mklabel msdos
        parted -s $DISK_PATH mkpart primary ext4 1MiB 100%
        parted -s $DISK_PATH set 1 boot on
    fi
    
    # Обновляем информацию о разделах
    partprobe $DISK_PATH
    sleep 2
}

# Функция для форматирования разделов
format_partitions() {
    echo "Форматирование разделов..."
    
    if [ "$UEFI_MODE" = true ]; then
        EFI_PART="${DISK_PATH}1"
        ROOT_PART="${DISK_PATH}2"
        
        mkfs.fat -F32 $EFI_PART
        mkfs.ext4 $ROOT_PART
    else
        ROOT_PART="${DISK_PATH}1"
        mkfs.ext4 $ROOT_PART
    fi
}

# Функция для монтирования разделов
mount_partitions() {
    echo "Монтирование разделов..."
    
    mount $ROOT_PART /mnt
    
    if [ "$UEFI_MODE" = true ]; then
        mkdir -p /mnt/boot/efi
        mount $EFI_PART /mnt/boot/efi
    fi
}

# Функция для установки базовой системы
install_base() {
    echo "Установка базовой системы..."
    pacstrap /mnt base base-devel linux linux-firmware
    
    echo "Генерация fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab
}

# Функция для настройки системы
configure_system() {
    echo "Настройка системы..."
    
    # Создаем скрипт для chroot
    cat > /mnt/install_chroot.sh << 'EOF'
#!/bin/bash

# Установка русского шрифта в устанавливаемой системе
pacman -S --noconfirm terminus-font

# Настройка времени
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Локализация
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# Устанавливаем русскую локаль по умолчанию
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Настройка клавиатуры
echo "KEYMAP=ru" > /etc/vconsole.conf
echo "FONT=cyr-sun16" >> /etc/vconsole.conf

# Настройка сети
read -p "Введите имя компьютера: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << HOSTS_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS_EOF

# Настройка параметров загрузки
echo "Настройка параметров загрузки..."

# Установка загрузчика
if [ -d /sys/firmware/efi ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc /dev/${DISK}
fi

# Настройка параметров GRUB в зависимости от выбора
if [ "$BOOT_STYLE" = "quiet" ]; then
    # Безопасная тихая загрузка без Plymouth
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
else
    # Стандартная загрузка с сообщениями
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=""/' /etc/default/grub
fi

# Обновляем конфиг GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Установка графической оболочки и дополнительных пакетов
if [ -n "$DE_PACKAGES" ]; then
    echo "Установка $DESKTOP_NAME..."
    pacman -S --noconfirm xorg-server xorg-xinit $DE_PACKAGES
    
    # Добавляем русскую локализацию для KDE
    if echo "$DE_PACKAGES" | grep -q "plasma"; then
        pacman -S --noconfirm plasma-meta-l10n-ru
    fi
fi

if [ -n "$ADDITIONAL_PACKAGES" ]; then
    echo "Установка дополнительных пакетов..."
    pacman -S --noconfirm $ADDITIONAL_PACKAGES
fi

# Включение служб
systemctl enable NetworkManager

if [ -n "$DM_PACKAGE" ]; then
    systemctl enable $DM_PACKAGE
fi

# Настройка пользователя
read -p "Введите имя пользователя: " USERNAME
useradd -m -G wheel -s /bin/bash $USERNAME
echo "Установите пароль для пользователя $USERNAME:"
passwd $USERNAME

# Настройка sudo
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Установка пароля root
echo "Установите пароль root:"
passwd

# Создание файла xinitrc для пользователя
if [ -n "$DE_PACKAGES" ] && [ "$DM_PACKAGE" = "" ]; then
    cat > /home/$USERNAME/.xinitrc << 'XINIT_EOF'
#!/bin/sh

# Автоматический запуск выбранной DE
case "$DE_PACKAGES" in
    *plasma*)
        exec startplasma-x11
        ;;
    *gnome*)
        exec gnome-session
        ;;
    *xfce*)
        exec startxfce4
        ;;
    *lxqt*)
        exec startlxqt
        ;;
    *)
        # Запуск twm по умолчанию
        exec twm
        ;;
esac
XINIT_EOF

    chown $USERNAME:$USERNAME /home/$USERNAME/.xinitrc
    chmod +x /home/$USERNAME/.xinitrc
fi

# Создание приветственного файла
cat > /home/$USERNAME/README.txt << WELCOME_EOF
Добро пожаловать в Arch Linux!

Установленная система:
- Графическая оболочка: $DESKTOP_NAME
- Стиль загрузки: $BOOT_STYLE
- Дисплей менеджер: $DM_PACKAGE
- Пользователь: $USERNAME

Если система зависает при загрузке:
1. При загрузке нажмите Esc чтобы увидеть сообщения
2. Или выберете в GRUB вариант с recovery mode
3. В консоли выполните: systemctl disable plymouth (если установлен)

Для отключения тихой загрузки:
Отредактируйте /etc/default/grub и уберите параметр "quiet splash"
Затем выполните: grub-mkconfig -o /boot/grub/grub.cfg

WELCOME_EOF

chown $USERNAME:$USERNAME /home/$USERNAME/README.txt

EOF

    chmod +x /mnt/install_chroot.sh
    
    # Передаем переменные в chroot
    echo "export DISK=$DISK" > /mnt/chroot_vars.sh
    echo "export ROOT_PART='$ROOT_PART'" >> /mnt/chroot_vars.sh
    echo "export DE_PACKAGES='$DE_PACKAGES'" >> /mnt/chroot_vars.sh
    echo "export DM_PACKAGE='$DM_PACKAGE'" >> /mnt/chroot_vars.sh
    echo "export DESKTOP_NAME='$DESKTOP_NAME'" >> /mnt/chroot_vars.sh
    echo "export ADDITIONAL_PACKAGES='$ADDITIONAL_PACKAGES'" >> /mnt/chroot_vars.sh
    echo "export BOOT_STYLE='$BOOT_STYLE'" >> /mnt/chroot_vars.sh
    chmod +x /mnt/chroot_vars.sh
    
    # Выполняем настройку в chroot
    arch-chroot /mnt /bin/bash -c "source /chroot_vars.sh && /install_chroot.sh"
}

# Функция для очистки
cleanup() {
    echo "Очистка..."
    rm -f /mnt/install_chroot.sh /mnt/chroot_vars.sh
    umount -R /mnt
    echo "Установка завершена!"
    echo "Графическая оболочка: $DESKTOP_NAME"
    echo "Стиль загрузки: $BOOT_STYLE"
    echo "Перезагрузите систему: reboot"
}

# Основной процесс установки
main() {
    echo "=== Установка Arch Linux ==="
    
    # Проверка интернета
    if ! ping -c 1 archlinux.org &> /dev/null; then
        echo "Ошибка: Нет подключения к интернету!"
        exit 1
    fi
    
    # Обновление ключей
    pacman -Sy --noconfirm archlinux-keyring
    
    select_desktop
    select_boot_style
    select_additional_packages
    select_disk
    
    read -p "Продолжить установку на $DISK_PATH с $DESKTOP_NAME? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        echo "Установка отменена."
        exit 0
    fi
    
    partition_disk
    format_partitions
    mount_partitions
    install_base
    configure_system
    cleanup
}

# Запуск основной функции
main "$@"
