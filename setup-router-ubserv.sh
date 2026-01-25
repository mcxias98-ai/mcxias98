#!/bin/bash

# Скрипт настройки маршрутизатора с USB-модемом и локальной сетью через Ethernet
# Автоматически запрашивает необходимые переменные у пользователя

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверка на запуск от root
if [ "$EUID" -ne 0 ]; then 
    print_error "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

# Шаг 1: Определение текущих сетевых интерфейсов
print_message "=== Определение сетевых интерфейсов ==="
echo "Текущие сетевые интерфейсы:"
ip -br link show | grep -v LOOPBACK

# Запрос интерфейса USB-модема
echo ""
print_message "Укажите интерфейс USB-модема (например: wwan0, eth1, enx...):"
read USB_INTERFACE

# Проверка существования интерфейса
if ! ip link show "$USB_INTERFACE" > /dev/null 2>&1; then
    print_error "Интерфейс $USB_INTERFACE не найден!"
    echo "Доступные интерфейсы:"
    ip -br link show | grep -v LOOPBACK
    exit 1
fi

# Запрос интерфейса Ethernet
echo ""
print_message "Укажите интерфейс Ethernet (например: eth0, enp1s0, eno1):"
read ETH_INTERFACE

# Проверка существования интерфейса
if ! ip link show "$ETH_INTERFACE" > /dev/null 2>&1; then
    print_error "Интерфейс $ETH_INTERFACE не найден!"
    echo "Доступные интерфейсы:"
    ip -br link show | grep -v LOOPBACK
    exit 1
fi

# Запрос подсети для локальной сети
echo ""
print_message "Укажите подсеть для локальной сети (например: 192.168.10.0/24):"
read SUBNET

# Извлечение IP-адреса шлюза из подсети
GATEWAY_IP=$(echo "$SUBNET" | cut -d'/' -f1 | awk -F'.' '{print $1"."$2"."$3".1"}')

# Запрос диапазона DHCP
echo ""
print_message "Укажите диапазон DHCP (например: 192.168.10.100,192.168.10.200):"
read DHCP_RANGE

# Запрос DNS серверов
echo ""
print_message "Укажите DNS серверы через запятую (по умолчанию: 8.8.8.8,8.8.4.4):"
read DNS_SERVERS
DNS_SERVERS=${DNS_SERVERS:-"8.8.8.8,8.8.4.4"}

# Подтверждение настроек
echo ""
print_warning "=== Подтверждение настроек ==="
echo "USB модем интерфейс: $USB_INTERFACE"
echo "Ethernet интерфейс: $ETH_INTERFACE"
echo "Подсеть: $SUBNET"
echo "Шлюз: $GATEWAY_IP"
echo "Диапазон DHCP: $DHCP_RANGE"
echo "DNS серверы: $DNS_SERVERS"
echo ""
read -p "Продолжить настройку? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_message "Настройка отменена."
    exit 0
fi

# Шаг 2: Обновление системы и установка пакетов
print_message "=== Установка необходимых пакетов ==="
apt update
apt install -y network-manager iptables-persistent netfilter-persistent isc-dhcp-server

# Шаг 3: Отключение NetworkManager для управляемых интерфейсов (чтобы не мешал)
print_message "=== Настройка NetworkManager ==="
if [ -f /etc/NetworkManager/NetworkManager.conf ]; then
    # Добавляем исключения для наших интерфейсов
    if ! grep -q "unmanaged-devices" /etc/NetworkManager/NetworkManager.conf; then
        sed -i '/^\[keyfile\]/a unmanaged-devices=interface-name:'$USB_INTERFACE';interface-name:'$ETH_INTERFACE /etc/NetworkManager/NetworkManager.conf
    fi
    systemctl restart NetworkManager
fi

# Шаг 4: Настройка Netplan
print_message "=== Настройка Netplan ==="

# Создаем резервную копию существующих конфигураций
mkdir -p /etc/netplan/backup
cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null || true

# Создаем новый конфигурационный файл
cat > /etc/netplan/01-router-config.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $USB_INTERFACE:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 100
      optional: true
    $ETH_INTERFACE:
      addresses:
        - $GATEWAY_IP/$(echo $SUBNET | cut -d'/' -f2)
      dhcp4: no
      dhcp6: no
EOF

# Применяем конфигурацию Netplan
netplan generate
netplan apply

# Шаг 5: Настройка DHCP сервера
print_message "=== Настройка DHCP сервера ==="

# Останавливаем DHCP сервер
systemctl stop isc-dhcp-server

# Создаем конфигурацию DHCP
cat > /etc/dhcp/dhcpd.conf << EOF
authoritative;

subnet $(echo $SUBNET | cut -d'/' -f1) netmask $(ipcalc -m $SUBNET | cut -d'=' -f2) {
  range $(echo $DHCP_RANGE | cut -d',' -f1) $(echo $DHCP_RANGE | cut -d',' -f2);
  option routers $GATEWAY_IP;
  option domain-name-servers $(echo $DNS_SERVERS | sed 's/,/, /g');
  option domain-name "local";
  default-lease-time 600;
  max-lease-time 7200;
}
EOF

# Указываем интерфейс для DHCP
echo "INTERFACESv4=\"$ETH_INTERFACE\"" > /etc/default/isc-dhcp-server

# Запускаем DHCP сервер
systemctl start isc-dhcp-server
systemctl enable isc-dhcp-server

# Шаг 6: Настройка маршрутизации и NAT
print_message "=== Настройка маршрутизации ==="

# Включаем IP forwarding
sed -i '/net.ipv4.ip_forward=/d' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Настраиваем iptables
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

# Правила NAT
iptables -t nat -A POSTROUTING -o $USB_INTERFACE -j MASQUERADE
iptables -A FORWARD -i $ETH_INTERFACE -o $USB_INTERFACE -j ACCEPT
iptables -A FORWARD -i $USB_INTERFACE -o $ETH_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешаем трафик в локальной сети
iptables -A INPUT -i $ETH_INTERFACE -j ACCEPT
iptables -A OUTPUT -o $ETH_INTERFACE -j ACCEPT

# Базовые правила безопасности
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохраняем правила iptables
netfilter-persistent save

# Шаг 7: Настройка DNS (опционально - dnsmasq)
print_message "=== Настройка DNS (dnsmasq) ==="
read -p "Установить dnsmasq для кэширования DNS? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    apt install -y dnsmasq
    cat > /etc/dnsmasq.conf << EOF
interface=$ETH_INTERFACE
dhcp-range=$(echo $DHCP_RANGE | cut -d',' -f1),$(echo $DHCP_RANGE | cut -d',' -f2),12h
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$(echo $DNS_SERVERS | cut -d',' -f1)
server=$(echo $DNS_SERVERS | cut -d',' -f1)
server=$(echo $DNS_SERVERS | cut -d',' -f2)
cache-size=1000
no-resolv
EOF
    systemctl restart dnsmasq
    systemctl enable dnsmasq
fi

# Шаг 8: Создание скрипта для сброса правил (на случай проблем)
print_message "=== Создание скрипта сброса ==="
cat > /usr/local/bin/reset-network.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Правила iptables сброшены"
EOF
chmod +x /usr/local/bin/reset-network.sh

# Шаг 9: Настройка автозагрузки правил
print_message "=== Настройка автозагрузки ==="
cat > /etc/systemd/system/apply-router-rules.service << EOF
[Unit]
Description=Apply router iptables rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore < /etc/iptables/rules.v4
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable apply-router-rules.service

# Шаг 10: Запись настроек в файл
cat > /root/router-settings.txt << EOF
Настройки маршрутизатора:
Дата настройки: $(date)
USB интерфейс: $USB_INTERFACE
Ethernet интерфейс: $ETH_INTERFACE
Подсеть: $SUBNET
Шлюз: $GATEWAY_IP
Диапазон DHCP: $DHCP_RANGE
DNS серверы: $DNS_SERVERS
EOF

# Шаг 11: Проверка настроек
print_message "=== Проверка настроек ==="
echo ""
echo "1. Проверка интерфейсов:"
ip -br addr show | grep -E "($USB_INTERFACE|$ETH_INTERFACE)"

echo ""
echo "2. Проверка маршрутизации:"
ip route show

echo ""
echo "3. Проверка NAT правил:"
iptables -t nat -L -n -v

echo ""
echo "4. Проверка форвардинга:"
cat /proc/sys/net/ipv4/ip_forward

echo ""
echo "5. Проверка DHCP сервера:"
systemctl status isc-dhcp-server --no-pager -l

# Шаг 12: Инструкция для пользователя
print_message "=== Настройка завершена! ==="
echo ""
echo "Инструкция по использованию:"
echo "1. Подключите USB-модем к этому серверу"
echo "2. Подключите другой ПК к порту $ETH_INTERFACE"
echo "3. Настройте на клиентском ПК автоматическое получение IP (DHCP)"
echo "4. Проверьте интернет на клиентском ПК"
echo ""
echo "Локальная сеть: $SUBNET"
echo "Шлюз (IP этого сервера): $GATEWAY_IP"
echo "Диапазон адресов для клиентов: $DHCP_RANGE"
echo ""
echo "Команды для проверки:"
echo "  • Статус DHCP: systemctl status isc-dhcp-server"
echo "  • Логи DHCP: tail -f /var/log/syslog | grep dhcp"
echo "  • Сброс правил: /usr/local/bin/reset-network.sh"
echo ""
echo "Настройки сохранены в: /root/router-settings.txt"
print_message "Перезагрузите систему для применения всех изменений!"
