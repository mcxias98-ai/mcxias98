#!/bin/bash

# Проверка на запуск от root
if [ "$EUID" -ne 0 ]; then 
    echo "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

echo "=== Исправление dnsmasq ==="

# 1. Останавливаем службу
systemctl stop dnsmasq

# 2. Отключаем автозапуск (если не нужен)
read -p "Отключить dnsmasq от автозагрузки? (рекомендуется, если не используется) [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl disable dnsmasq
    echo "dnsmasq отключен от автозагрузки"
fi

# 3. Проверяем конфигурацию
echo ""
echo "Проверка конфигурации dnsmasq..."
dnsmasq --test 2>&1

# 4. Ищем конфликты
echo ""
echo "Поиск конфликтов портов..."
ss -tulpn | grep :53

# 5. Решение вариантов
echo ""
echo "Выберите вариант решения:"
echo "1) Настроить dnsmasq для работы с systemd-resolved"
echo "2) Отключить dnsmasq и использовать только systemd-resolved"
echo "3) Настроить dnsmasq как основной DNS (отключить systemd-resolved)"
echo "4) Удалить dnsmasq"
read -p "Ваш выбор [1-4]: " choice

case $choice in
    1)
        # Вариант 1: Настройка совместной работы
        echo "Настройка совместной работы dnsmasq и systemd-resolved..."
        
        # Настройка dnsmasq для прослушивания только на локальном интерфейсе
        cat > /etc/dnsmasq.conf << 'EOF'
# Слушаем только на локальном интерфейсе и Ethernet
listen-address=127.0.0.1
listen-address=192.168.10.1  # Измените на ваш IP шлюза
bind-interfaces

# DNS настройки
server=8.8.8.8
server=8.8.4.4
cache-size=1000
no-resolv
EOF
        
        # Настройка systemd-resolved для использования dnsmasq
        sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
        echo "DNS=127.0.0.1" >> /etc/systemd/resolved.conf
        
        systemctl restart systemd-resolved
        ;;
    
    2)
        # Вариант 2: Отключение dnsmasq
        echo "Отключение dnsmasq..."
        systemctl stop dnsmasq
        systemctl disable dnsmasq
        systemctl restart systemd-resolved
        echo "Используется systemd-resolved"
        ;;
    
    3)
        # Вариант 3: dnsmasq как основной DNS
        echo "Настройка dnsmasq как основного DNS..."
        
        # Останавливаем systemd-resolved
        systemctl stop systemd-resolved
        systemctl disable systemd-resolved
        
        # Правильная конфигурация dnsmasq
        cat > /etc/dnsmasq.conf << 'EOF'
# Слушаем на всех интерфейсах
listen-address=127.0.0.1
listen-address=192.168.10.1  # Измените на ваш IP шлюза
bind-interfaces

# DHCP настройки
dhcp-range=192.168.10.100,192.168.10.200,12h
dhcp-option=3,192.168.10.1
dhcp-option=6,8.8.8.8,8.8.4.4

# DNS настройки
server=8.8.8.8
server=8.8.4.4
cache-size=1000
no-resolv
EOF
        
        # Убираем resolvconf
        if [ -f /etc/resolv.conf ]; then
            rm /etc/resolv.conf
            echo "nameserver 127.0.0.1" > /etc/resolv.conf
        fi
        ;;
    
    4)
        # Вариант 4: Удаление dnsmasq
        echo "Удаление dnsmasq..."
        apt remove --purge -y dnsmasq
        systemctl restart systemd-resolved
        echo "dnsmasq удален"
        ;;
    
    *)
        echo "Неверный выбор"
        ;;
esac

# Запускаем/перезапускаем службы
if systemctl is-enabled dnsmasq >/dev/null 2>&1; then
    systemctl restart dnsmasq
    systemctl status dnsmasq --no-pager
fi

echo ""
echo "Проверка портов после настройки:"
ss -tulpn | grep :53

echo ""
echo "=== Готово! ==="