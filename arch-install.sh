#!/bin/bash

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
    echo "1) Тихая загрузка с лого Arch Linux (рекомендуется)"
    echo "2) Тихая загрузка с лого производителя оборудования"
    echo "3) Стандартная загрузка с сообщениями"
    echo ""
    
    read -p "Введите номер варианта (1-3): " BOOT_CHOICE
    
    case $BOOT_CHOICE in
        1)
            BOOT_STYLE="arch_logo"
            echo "Выбрана тихая загрузка с лого Arch Linux"
            ;;
        2)
            BOOT_STYLE="vendor_logo"
            echo "Выбрана тихая загрузка с лого производителя"
            ;;
        3)
            BOOT_STYLE="verbose"
            echo "Выбрана стандартная загрузка с сообщениями"
            ;;
        *)
            BOOT_STYLE="arch_logo"
            echo "Неверный выбор, используется тихая загрузка с лого Arch Linux"
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
        ADDITIONAL_PACKAGES+=" vlc firefox"
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

# Функция для настройки тихой загрузки (ДОБАВЛЕНО НАСТРОЙКА ТИХОЙ ЗАГРУЗКИ)
setup_quiet_boot() {
    echo "Настройка тихой загрузки..."
    
    # Создаем каталог для Plymouth (если нужно)
    mkdir -p /mnt/usr/share/plymouth/themes
    
    # Копируем тему Arch Linux для Plymouth
    cat > /mnt/usr/share/plymouth/themes/arch-logo/arch-logo.plymouth << 'PLYMOUTH_EOF'
[Plymouth Theme]
Name=Arch Logo
Description=A theme that features the Arch Linux logo
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/arch-logo
ScriptFile=/usr/share/plymouth/themes/arch-logo/arch-logo.script
PLYMOUTH_EOF

    cat > /mnt/usr/share/plymouth/themes/arch-logo/arch-logo.script << 'SCRIPT_EOF'
wallpaper_image = Image("arch-logo.png");
background_color = (0.0, 0.0, 0.0);
logo_sprite = Sprite();
logo_sprite.SetImage(wallpaper_image);

Window.SetBackgroundTopColor (background_color);
Window.SetBackgroundBottomColor (background_color);

fun message_callback (text) {
}

Plymouth.SetRefreshFunction (function () {
    logo_width = logo_sprite.GetWidth();
    logo_height = logo_sprite.GetHeight();
    x = Window.GetWidth() / 2 - logo_width / 2;
    y = Window.GetHeight() / 2 - logo_height / 2;
    logo_sprite.SetX (x);
    logo_sprite.SetY (y);
});

Plymouth.SetMessageFunction (message_callback);
SCRIPT_EOF

    # Создаем простой логотип Arch (базовый PNG в виде текстового файла)
    # В реальной системе лучше использовать готовые темы из AUR
    echo "iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAIAAAAlC+aJAAAABnRSTlMAAAAAAABupgeRAAAACXBIWXMAAA7EAAAOxAGVKw4bAAABTUlEQVRoge3aQW7CMBBA0T8pF6HiAFQcgIoDUHGAVhyAigNQcYBWHICKA1BxgFYcgIoDUHGAKQ5AxQGoOMAUX4CKA1BxgCm+ABUHoOIAU3wBKg5AxQGm+AJUHICKA0zxBag4ABUHmOILUHEAKg4wxReg4gBUHGCKL0DFAag4wBRfgIoDUHGAKb4AFQeg4gBTfAEqDkDFAab4AlQcgIoDTPEFqDgAFQeY4gtQcQAqDjDFF6DiAFQcYIovQMUBqDjAFF+AigNQcYApvgAVB6DiAFN8ASoOQMUBpvgCVByAigNM8QWoOAAVB5jiC1BxACoOMMUXoOIAVBxgii9AxQGoOMAUX4CKA1BxgCm+ABUHoOIAU3wBKg5AxQGm+AJUHICKA0zxBag4ABUHmOILUHEAKg4wxReg4gBUHGCKL0DFAag4wBRfgIoDUHGAKb4AFQeg4gBTfAEqDkDFAab4AlQcgIoDTPEFqDgAFQeY4n8BdD1QpVl5p5AAAAAASUVORK5CYII=" | base64 -d > /mnt/usr/share/plymouth/themes/arch-logo/arch-logo.png 2>/dev/null || true
}

# Функция для настройки системы
configure_system() {
    echo "Настройка системы..."
    
    # Настраиваем тихую загрузку если выбрано (ДОБАВЛЕНО)
    if [ "$BOOT_STYLE" != "verbose" ]; then
        setup_quiet_boot
    fi
    
    # Создаем скрипт для chroot
    cat > /mnt/install_chroot.sh << 'EOF'
#!/bin/bash

# Настройка времени
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# Локализация
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=ru_RU.UTF-8" > /etc/locale.conf

# Настройка сети
read -p "Введите имя компьютера: " HOSTNAME
echo "$HOSTNAME" > /etc/hostname

cat > /etc/hosts << HOSTS_EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS_EOF

# НАСТРОЙКА ТИХОЙ ЗАГРУЗКИ - ДОБАВЛЕНО ПАРАМЕТРЫ ЯДРА
echo "Настройка параметров загрузки..."

# Создаем файл для настроек ядра
cat > /etc/kernel/cmdline << CMDLINE_EOF
root=UUID=$(blkid -s UUID -o value $ROOT_PART) rw
CMDLINE_EOF

# Добавляем параметры для тихой загрузки
if [ "$BOOT_STYLE" != "verbose" ]; then
    echo "quiet splash loglevel=3 vt.global_cursor_default=0" >> /etc/kernel/cmdline
    
    if [ "$BOOT_STYLE" = "arch_logo" ]; then
        echo "plymouth.enable=1 plymouth.theme=arch-logo" >> /etc/kernel/cmdline
    else
        echo "plymouth.enable=0" >> /etc/kernel/cmdline
    fi
fi

# Установка загрузчика
if [ -d /sys/firmware/efi ]; then
    pacman -S --noconfirm grub efibootmgr
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    
    # Настройка GRUB для тихой загрузки - ДОБАВЛЕНО
    if [ "$BOOT_STYLE" != "verbose" ]; then
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"/' /etc/default/grub
        sed -i 's/^#GRUB_TERMINAL_OUTPUT=console/GRUB_TERMINAL_OUTPUT=console/' /etc/default/grub
        sed -i 's/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=""/' /etc/default/grub
    fi
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc /dev/${DISK}
    
    # Настройка GRUB для тихой загрузки - ДОБАВЛЕНО
    if [ "$BOOT_STYLE" != "verbose" ]; then
        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"/' /etc/default/grub
        sed -i 's/^#GRUB_TERMINAL_OUTPUT=console/GRUB_TERMINAL_OUTPUT=console/' /etc/default/grub
    fi
fi

grub-mkconfig -o /boot/grub/grub.cfg

# Установка Plymouth для анимированной заставки - ДОБАВЛЕНО
if [ "$BOOT_STYLE" != "verbose" ]; then
    echo "Установка Plymouth для заставки..."
    pacman -S --noconfirm plymouth
    
    # Настройка хуков для initramfs
    sed -i 's/^HOOKS=.*/HOOKS=(base udev plymouth autodetect modconf kms keyboard keymap consolefont block filesystems fsck)/' /etc/mkinitcpio.conf
    
    # Пересборка initramfs
    mkinitcpio -P
fi

# Установка графической оболочки и дополнительных пакетов
if [ -n "$DE_PACKAGES" ]; then
    echo "Установка $DESKTOP_NAME..."
    pacman -S --noconfirm xorg-server xorg-xinit $DE_PACKAGES
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

Настройки загрузки:
- Тихая загрузка: $( [ "$BOOT_STYLE" != "verbose" ] && echo "Да" || echo "Нет" )
- Анимированная заставка: $( [ "$BOOT_STYLE" = "arch_logo" ] && echo "Arch Linux" || echo "Производитель" )

Для запуска графической среды:
- При наличии дисплей менеджера: система загрузится автоматически
- Без дисплей менеджера: выполните 'startx' из консоли

Советы:
- Обновите систему: sudo pacman -Syu
- Ищите пакеты: pacman -Ss <имя>
- Для дополнительных тем Plymouth установите: yay -S plymouth-theme-arch-logo
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
    echo "=== Установка Arch Linux с тихой загрузкой ==="
    
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
    
    read -p "Продолжить установку на $DISK_PATH с $DESKTOP_NAME и стилем загрузки $BOOT_STYLE? (y/N): " CONFIRM
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
