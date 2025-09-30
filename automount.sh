#!/bin/bash

# Автоматический поиск Arch Linux разделов
echo "Поиск Arch Linux разделов..."

# Ищем корневой раздел (обычно ext4 с Arch)
ROOT_PART=$(lsblk -lf | grep ext4 | grep -v loop | awk '{print $1}' | head -1)
EFI_PART=$(lsblk -lf | grep vfat | grep -v loop | awk '{print $1}' | head -1)

if [ -z "$ROOT_PART" ]; then
    echo "Корневой раздел не найден!"
    lsblk -f
    exit 1
fi

echo "Найден корневой раздел: /dev/$ROOT_PART"
if [ -n "$EFI_PART" ]; then
    echo "Найден EFI раздел: /dev/$EFI_PART"
fi

# Монтирование
mount "/dev/$ROOT_PART" /mnt

if [ -n "$EFI_PART" ]; then
    mkdir -p /mnt/boot/efi
    mount "/dev/$EFI_PART" /mnt/boot/efi
fi

# Виртуальные ФС
mount --bind /dev /mnt/dev
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mount --bind /run /mnt/run
mount --bind /tmp /mnt/tmp

echo "Система смонтирована. Запуск chroot..."
chroot /mnt
