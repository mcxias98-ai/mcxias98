#!/bin/bash
# DHCP Server Manager for Ubuntu Server 24.04
# Interactive diagnostic and configuration tool

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Основные переменные
DEFAULT_INTERFACE="enp2s0"
DEFAULT_SUBNET="192.168.10.0/24"
DEFAULT_SERVER_IP="192.168.10.1"
DEFAULT_DHCP_RANGE_START="192.168.10.100"
DEFAULT_DHCP_RANGE_END="192.168.10.200"
BACKUP_DIR="/root/network_backup_$(date +%Y%m%d_%H%M%S)"
NETWORKD_DIR="/etc/systemd/network"

# Функция для отображения меню
show_menu() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         DHCP Server Manager - Ubuntu Server 24.04            ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} 1.  Полная диагностика сети и DHCP сервера              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 2.  Настроить DHCP сервер (isc-dhcp-server)            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 3.  Настроить DHCP сервер (dnsmasq - проще)            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 4.  Настроить DHCP сервер (systemd-networkd - встроенный) ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 5.  Проверить и исправить IP адрес на интерфейсе       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 6.  Показать логи DHCP сервера                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 7.  Проверить клиентов DHCP (аренды)                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 8.  Мониторинг DHCP трафика в реальном времени         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 9.  Управление systemd-networkd                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 10. Просмотр конфигурации systemd-networkd             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 11. Сбросить все сетевые настройки по умолчанию        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 12. Резервное копирование сетевых конфигураций         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 13. Восстановить из резервной копии                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 14. Установить/переустановить DHCP сервер              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 15. Перезапустить сетевые службы                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 16. Настроить статический IP на интерфейсе             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 17. Показать текущую конфигурацию сети                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 18. Тестирование соединения                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 19. Управление IP Forwarding (перенаправление трафика) ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 20. Управление UFW (брандмауэр)                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 21. Управление iptables (правила фаервола)             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 22. Выход                                             ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -n "Выберите опцию [1-22]: "
}

# Функция для проверки прав суперпользователя
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Этот скрипт должен запускаться с правами root!${NC}"
        echo "Используйте: sudo $0"
        exit 1
    fi
}

# Функция 1: Полная диагностика
full_diagnostic() {
    echo -e "\n${GREEN}=== ПОЛНАЯ ДИАГНОСТИКА СЕТИ И DHCP СЕРВЕРА ===${NC}\n"
    
    echo -e "${YELLOW}1. СЕТЕВЫЕ ИНТЕРФЕЙСЫ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c addr show
    echo ""
    
    echo -e "${YELLOW}2. СОСТОЯНИЕ ИНТЕРФЕЙСОВ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c link show
    echo ""
    
    echo -e "${YELLOW}3. ТАБЛИЦА МАРШРУТИЗАЦИИ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c route show
    echo ""
    
    echo -e "${YELLOW}4. ARP ТАБЛИЦА:${NC}"
    echo "══════════════════════════════════════════"
    ip -c neigh show
    echo ""
    
    echo -e "${YELLOW}5. СЛУЖБЫ DHCP:${NC}"
    echo "══════════════════════════════════════════"
    
    if systemctl is-active systemd-networkd >/dev/null 2>&1; then
        echo -e "systemd-networkd: ${GREEN}АКТИВЕН${NC}"
        systemctl status systemd-networkd --no-pager -l | head -10
    else
        echo -e "systemd-networkd: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
    
    if systemctl is-active isc-dhcp-server >/dev/null 2>&1; then
        echo -e "isc-dhcp-server: ${GREEN}АКТИВЕН${NC}"
        systemctl status isc-dhcp-server --no-pager -l | head -10
    else
        echo -e "isc-dhcp-server: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
    
    if systemctl is-active dnsmasq >/dev/null 2>&1; then
        echo -e "dnsmasq: ${GREEN}АКТИВЕН${NC}"
        systemctl status dnsmasq --no-pager -l | head -10
    else
        echo -e "dnsmasq: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
    
    echo -e "${YELLOW}6. ОТКРЫТЫЕ ПОРТЫ DHCP (67,68):${NC}"
    echo "══════════════════════════════════════════"
    ss -tulpn | grep -E ':67|:68' | grep -v "127.0.0.1" || echo "Порты не открыты"
    echo ""
    
    echo -e "${YELLOW}7. КОНФИГУРАЦИОННЫЕ ФАЙЛЫ:${NC}"
    echo "══════════════════════════════════════════"
    
    if [[ -d "/etc/netplan" ]] && ls /etc/netplan/*.yaml 2>/dev/null; then
        echo "Netplan конфиги:"
        ls -la /etc/netplan/
        for file in /etc/netplan/*.yaml; do
            echo -e "\nФайл: $file"
            cat "$file" 2>/dev/null || echo "Не удалось прочитать"
        done
    else
        echo "Netplan конфиги не найдены"
    fi
    echo ""
    
    if [[ -d "$NETWORKD_DIR" ]]; then
        echo "Конфиги systemd-networkd:"
        ls -la "$NETWORKD_DIR/"
        find "$NETWORKD_DIR" -maxdepth 1 -name "*.network" -type f | while read -r file; do
            echo -e "\nФайл: $file"
            cat "$file" 2>/dev/null || echo "Не удалось прочитать"
        done
    fi
    echo ""
    
    if [[ -f "/etc/dhcp/dhcpd.conf" ]]; then
        echo "Конфиг isc-dhcp-server (/etc/dhcp/dhcpd.conf):"
        cat /etc/dhcp/dhcpd.conf | head -20
    fi
    echo ""
    
    if [[ -f "/etc/default/isc-dhcp-server" ]]; then
        echo "Интерфейсы isc-dhcp-server:"
        cat /etc/default/isc-dhcp-server
    fi
    echo ""
    
    if [[ -f "/etc/dnsmasq.conf" ]]; then
        echo "Конфиг dnsmasq (первые 20 строк):"
        cat /etc/dnsmasq.conf | head -20
    fi
    echo ""
    
    echo -e "${YELLOW}8. ПОСЛЕДНИЕ ЛОГИ DHCP:${NC}"
    echo "══════════════════════════════════════════"
    echo "Логи systemd-networkd:"
    journalctl -u systemd-networkd -n 10 --no-pager 2>/dev/null || echo "Логи недоступны"
    echo ""
    
    echo -e "${YELLOW}9. АРЕНДЫ DHCP (systemd-networkd):${NC}"
    echo "══════════════════════════════════════════"
    if [[ -d "/run/systemd/netif/leases" ]]; then
        echo "Активные аренды systemd-networkd:"
        ls -la /run/systemd/netif/leases/ 2>/dev/null
        for lease in /run/systemd/netif/leases/*; do
            if [[ -f "$lease" ]]; then
                echo -e "\nФайл: $(basename "$lease")"
                cat "$lease"
            fi
        done 2>/dev/null
    else
        echo "Аренды systemd-networkd не найдены"
    fi
    echo ""
    
    echo -e "${YELLOW}10. ИНФОРМАЦИЯ ЧЕРЕЗ NETWORKCTL:${NC}"
    echo "══════════════════════════════════════════"
    which networkctl >/dev/null && networkctl list 2>/dev/null || echo "networkctl не установлен"
    echo ""
    
    echo -e "${YELLOW}11. СОСТОЯНИЕ IP FORWARDING:${NC}"
    echo "══════════════════════════════════════════"
    echo "IPv4 Forwarding: $(sysctl -n net.ipv4.ip_forward)"
    echo "IPv6 Forwarding: $(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || echo 'N/A')"
    echo ""

    echo -e "${YELLOW}12. СОСТОЯНИЕ БРАНДМАУЭРА:${NC}"
    echo "══════════════════════════════════════════"
    # Проверяем UFW
    if command -v ufw &> /dev/null; then
        ufw status | head -3
    else
        echo "UFW не установлен"
    fi

    # Проверяем iptables
    echo -e "\nОсновные цепочки iptables:"
    iptables -L -n | grep -E "Chain (INPUT|FORWARD|OUTPUT)" | head -10

    # ... остальной существующий код ...

    read -p "Нажмите Enter для продолжения..."
}

# Функция 2: Настройка isc-dhcp-server
setup_isc_dhcp() {
    echo -e "\n${GREEN}=== НАСТРОЙКА ISC-DHCP-SERVER ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    read -p "Введите IP адрес сервера [$DEFAULT_SERVER_IP]: " server_ip
    server_ip=${server_ip:-$DEFAULT_SERVER_IP}
    
    read -p "Введите начальный IP пула DHCP [$DEFAULT_DHCP_RANGE_START]: " range_start
    range_start=${range_start:-$DEFAULT_DHCP_RANGE_START}
    
    read -p "Введите конечный IP пула DHCP [$DEFAULT_DHCP_RANGE_END]: " range_end
    range_end=${range_end:-$DEFAULT_DHCP_RANGE_END}
    
    subnet=$(echo $server_ip | cut -d'.' -f1-3)
    
    echo -e "\n${YELLOW}Настройка netplan...${NC}"
    cat > /tmp/netplan-config.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses:
        - $server_ip/24
      dhcp4: no
      dhcp6: no
      optional: false
EOF
    
    echo "Применяем настройки netplan..."
    cp /tmp/netplan-config.yaml /etc/netplan/00-dhcp-server.yaml 2>/dev/null
    netplan apply
    
    echo -e "\n${YELLOW}Проверяем IP на интерфейсе...${NC}"
    ip addr show $interface 2>/dev/null || echo "Интерфейс $interface не найден"
    
    if ! dpkg -l | grep -q isc-dhcp-server; then
        echo "Устанавливаем isc-dhcp-server..."
        apt update && apt install -y isc-dhcp-server
    fi
    
    echo -e "\n${YELLOW}Настраиваем dhcpd.conf...${NC}"
    mkdir -p /etc/dhcp
    cat > /etc/dhcp/dhcpd.conf << EOF
ddns-update-style none;
authoritative;
log-facility local7;

subnet ${subnet}.0 netmask 255.255.255.0 {
    range ${range_start} ${range_end};
    option routers ${server_ip};
    option subnet-mask 255.255.255.0;
    option broadcast-address ${subnet}.255;
    option domain-name-servers 8.8.8.8, 8.8.4.4;
    default-lease-time 600;
    max-lease-time 7200;
}
EOF
    
    echo -e "\n${YELLOW}Настраиваем интерфейсы...${NC}"
    cat > /etc/default/isc-dhcp-server << EOF
INTERFACESv4="$interface"
INTERFACESv6=""
EOF
    
    mkdir -p /var/lib/dhcp
    touch /var/lib/dhcp/dhcpd.leases
    
    echo -e "\n${YELLOW}Проверяем синтаксис конфигурации...${NC}"
    if which dhcpd >/dev/null && dhcpd -t 2>/dev/null; then
        echo -e "${GREEN}Синтаксис конфигурации правильный!${NC}"
        
        systemctl stop isc-dhcp-server 2>/dev/null
        systemctl start isc-dhcp-server
        systemctl enable isc-dhcp-server
        
        echo -e "\n${GREEN}Статус службы:${NC}"
        systemctl status isc-dhcp-server --no-pager -l | head -10
    else
        echo -e "${RED}Ошибка в синтаксисе конфигурации!${NC}"
    fi
    
    echo -e "\n${YELLOW}Проверяем открытые порты...${NC}"
    ss -tulpn | grep :67 || echo "Порт 67 не открыт"
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 3: Настройка dnsmasq
setup_dnsmasq() {
    echo -e "\n${GREEN}=== НАСТРОЙКА DNSMASQ ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    read -p "Введите IP адрес сервера [$DEFAULT_SERVER_IP]: " server_ip
    server_ip=${server_ip:-$DEFAULT_SERVER_IP}
    
    read -p "Введите начальный IP пула DHCP [$DEFAULT_DHCP_RANGE_START]: " range_start
    range_start=${range_start:-$DEFAULT_DHCP_RANGE_START}
    
    read -p "Введите конечный IP пула DHCP [$DEFAULT_DHCP_RANGE_END]: " range_end
    range_end=${range_end:-$DEFAULT_DHCP_RANGE_END}
    
    echo -e "\n${YELLOW}Настройка netplan...${NC}"
    cat > /tmp/netplan-config.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses:
        - $server_ip/24
      dhcp4: no
      dhcp6: no
EOF
    
    cp /tmp/netplan-config.yaml /etc/netplan/00-dnsmasq-server.yaml 2>/dev/null
    netplan apply
    
    systemctl stop isc-dhcp-server 2>/dev/null
    systemctl disable isc-dhcp-server 2>/dev/null
    
    if ! dpkg -l | grep -q dnsmasq; then
        echo "Устанавливаем dnsmasq..."
        apt update && apt install -y dnsmasq
    fi
    
    echo -e "\n${YELLOW}Настраиваем dnsmasq...${NC}"
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup 2>/dev/null || true
    
    cat > /etc/dnsmasq.conf << EOF
interface=$interface
dhcp-range=$range_start,$range_end,255.255.255.0,12h
dhcp-option=option:router,$server_ip
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
bind-interfaces
EOF
    
    echo -e "\n${YELLOW}Перезапускаем dnsmasq...${NC}"
    systemctl stop dnsmasq 2>/dev/null
    systemctl start dnsmasq
    systemctl enable dnsmasq
    
    echo -e "\n${GREEN}Статус службы:${NC}"
    systemctl status dnsmasq --no-pager -l | head -10
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 4: Настройка DHCP через systemd-networkd
setup_systemd_networkd_dhcp() {
    echo -e "\n${GREEN}=== НАСТРОЙКА DHCP СЕРВЕРА (SYSTEMD-NETWORKD) ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo -e "\n${YELLOW}Выберите режим:${NC}"
    echo "1. Только DHCP сервер (раздача адресов клиентам)"
    echo "2. DHCP сервер + статический IP на интерфейсе"
    echo "3. DHCP клиент (получение адреса)"
    read -p "Выберите опцию [1-3]: " mode_choice
    
    mkdir -p $NETWORKD_DIR
    
    case $mode_choice in
        1)
            # Только DHCP сервер
            read -p "Введите подсеть для раздачи [192.168.10.0/24]: " subnet
            subnet=${subnet:-"192.168.10.0/24"}
            
            cat > $NETWORKD_DIR/10-$interface.network << EOF
[Match]
Name=$interface

[Network]
Address=$subnet
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=100
DNS=8.8.8.8 8.8.4.4
EOF
            ;;
            
        2)
            # DHCP сервер + статический IP
            read -p "Введите статический IP для сервера [192.168.10.1/24]: " static_ip
            static_ip=${static_ip:-"192.168.10.1/24"}
            
            cat > $NETWORKD_DIR/10-$interface.network << EOF
[Match]
Name=$interface

[Network]
Address=$static_ip
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=100
DNS=8.8.8.8 8.8.4.4
EOF
            ;;
            
        3)
            # DHCP клиент
            cat > $NETWORKD_DIR/10-$interface.network << EOF
[Match]
Name=$interface

[Network]
DHCP=yes
EOF
            ;;
            
        *)
            echo "Неверный выбор"
            return
            ;;
    esac
    
    echo -e "\n${YELLOW}Отключаем другие DHCP серверы...${NC}"
    systemctl stop isc-dhcp-server 2>/dev/null
    systemctl stop dnsmasq 2>/dev/null
    
    echo -e "\n${YELLOW}Запускаем systemd-networkd...${NC}"
    systemctl enable systemd-networkd
    systemctl restart systemd-networkd
    
    echo -e "\n${GREEN}Статус:${NC}"
    systemctl status systemd-networkd --no-pager -l | head -10
    
    sleep 2
    echo -e "\n${GREEN}Конфигурация интерфейса $interface:${NC}"
    ip addr show $interface
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 5: Проверить и исправить IP адрес
fix_ip_address() {
    echo -e "\n${GREEN}=== ПРОВЕРКА И ИСПРАВЛЕНИЕ IP АДРЕСА ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo -e "\n${YELLOW}Текущее состояние:${NC}"
    ip addr show $interface 2>/dev/null || echo "Интерфейс не найден"
    
    echo -e "\n${YELLOW}Опции:${NC}"
    echo "1. Назначить статический IP"
    echo "2. Включить DHCP"
    echo "3. Сбросить настройки"
    echo "4. Проверить соединение"
    read -p "Выберите опцию [1-4]: " ip_option
    
    case $ip_option in
        1)
            read -p "Введите IP адрес [192.168.10.1]: " static_ip
            static_ip=${static_ip:-"192.168.10.1"}
            
            echo "Назначаем статический IP $static_ip/24..."
            ip addr flush dev $interface 2>/dev/null
            ip addr add $static_ip/24 dev $interface 2>/dev/null
            ip link set $interface up 2>/dev/null
            
            ip addr show $interface
            ;;
        2)
            echo "Включаем DHCP..."
            dhclient -r $interface 2>/dev/null
            dhclient $interface 2>/dev/null &
            
            sleep 3
            ip addr show $interface
            ;;
        3)
            echo "Сбрасываем настройки..."
            ip addr flush dev $interface 2>/dev/null
            ip link set $interface down 2>/dev/null
            sleep 1
            ip link set $interface up 2>/dev/null
            
            ip addr show $interface
            ;;
        4)
            echo "Проверяем соединение..."
            ethtool $interface 2>/dev/null | grep -E "Link|Speed" || echo "ethtool не доступен"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 6: Показать логи DHCP сервера
show_dhcp_logs() {
    echo -e "\n${GREEN}=== ЛОГИ DHCP СЕРВЕРА ===${NC}\n"
    
    echo "1. Логи systemd-networkd"
    echo "2. Логи isc-dhcp-server"
    echo "3. Логи dnsmasq"
    echo "4. Общие системные логи"
    read -p "Выберите опцию [1-4]: " log_option
    
    case $log_option in
        1)
            echo -e "\n${YELLOW}Логи systemd-networkd:${NC}"
            journalctl -u systemd-networkd -n 30 --no-pager 2>/dev/null || echo "Логи недоступны"
            ;;
        2)
            echo -e "\n${YELLOW}Логи isc-dhcp-server:${NC}"
            journalctl -u isc-dhcp-server -n 30 --no-pager 2>/dev/null || echo "Логи недоступны"
            ;;
        3)
            echo -e "\n${YELLOW}Логи dnsmasq:${NC}"
            journalctl -u dnsmasq -n 30 --no-pager 2>/dev/null || echo "Логи недоступны"
            ;;
        4)
            echo -e "\n${YELLOW}Общие логи:${NC}"
            tail -50 /var/log/syslog 2>/dev/null | grep -i "dhcp\|network" || echo "Логи не найдены"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 7: Проверить клиентов DHCP
check_dhcp_clients() {
    echo -e "\n${GREEN}=== ПРОВЕРКА КЛИЕНТОВ DHCP ===${NC}\n"
    
    echo -e "${YELLOW}Активные аренды:${NC}"
    echo "══════════════════════════════════════════"
    
    if [[ -f "/var/lib/dhcp/dhcpd.leases" ]]; then
        echo "isc-dhcp-server leases:"
        grep -A4 "lease " /var/lib/dhcp/dhcpd.leases | tail -20 || echo "Аренды не найдены"
    fi
    
    if [[ -f "/var/lib/misc/dnsmasq.leases" ]]; then
        echo -e "\ndnsmasq leases:"
        cat /var/lib/misc/dnsmasq.leases 2>/dev/null || echo "Аренды не найдены"
    fi
    
    if [[ -d "/run/systemd/netif/leases" ]]; then
        echo -e "\nsystemd-networkd leases:"
        ls /run/systemd/netif/leases/ 2>/dev/null || echo "Аренды не найдены"
    fi
    
    echo -e "\n${YELLOW}ARP таблица:${NC}"
    ip neigh show 2>/dev/null || echo "ARP таблица пуста"
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 8: Мониторинг DHCP трафика
monitor_dhcp_traffic() {
    echo -e "\n${GREEN}=== МОНИТОРИНГ DHCP ТРАФИКА ===${NC}\n"
    
    if ! command -v tcpdump &> /dev/null; then
        echo "Установка tcpdump..."
        apt update && apt install -y tcpdump
    fi
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo "1. Краткий мониторинг"
    echo "2. Подробный мониторинг"
    echo "3. Запись в файл"
    read -p "Выберите опцию [1-3]: " monitor_option
    
    echo -e "\n${GREEN}Начинаем мониторинг...${NC}"
    echo "Нажмите Ctrl+C для остановки"
    
    case $monitor_option in
        1)
            timeout 10 tcpdump -i $interface -n "port 67 or port 68" 2>/dev/null || echo "Мониторинг не удался"
            ;;
        2)
            timeout 10 tcpdump -i $interface -n -X "port 67 or port 68" 2>/dev/null || echo "Мониторинг не удался"
            ;;
        3)
            pcap_file="/tmp/dhcp_capture_$(date +%s).pcap"
            echo "Записываем в $pcap_file..."
            timeout 10 tcpdump -i $interface -n -w $pcap_file "port 67 or port 68" 2>/dev/null
            echo "Запись завершена"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 9: Управление systemd-networkd
manage_systemd_networkd() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ SYSTEMD-NETWORKD ===${NC}\n"
    
    echo "1. Статус"
    echo "2. Перезапуск"
    echo "3. Перезагрузка конфигурации"
    echo "4. Список устройств"
    echo "5. Включить/выключить"
    read -p "Выберите опцию [1-5]: " networkd_option
    
    case $networkd_option in
        1)
            systemctl status systemd-networkd --no-pager -l
            ;;
        2)
            systemctl restart systemd-networkd
            echo "Перезапущено"
            ;;
        3)
            systemctl reload systemd-networkd
            echo "Конфигурация перезагружена"
            ;;
        4)
            which networkctl >/dev/null && networkctl list || echo "networkctl не найден"
            ;;
        5)
            if systemctl is-enabled systemd-networkd >/dev/null; then
                systemctl disable systemd-networkd
                systemctl stop systemd-networkd
                echo "Отключено"
            else
                systemctl enable systemd-networkd
                systemctl start systemd-networkd
                echo "Включено"
            fi
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 10: Просмотр конфигурации systemd-networkd
view_systemd_networkd_config() {
    echo -e "\n${GREEN}=== КОНФИГУРАЦИЯ SYSTEMD-NETWORKD ===${NC}\n"

    if [[ ! -d "$NETWORKD_DIR" ]]; then
        echo "Директория не существует"
        return
    fi

    echo "Файлы конфигурации:"
    ls -la "$NETWORKD_DIR/" 2>/dev/null || echo "Нет файлов"

    echo -e "\nСодержимое файлов .network:"
    for file in "$NETWORKD_DIR"/*.network; do
        if [[ -f "$file" ]]; then
            echo -e "\n=== $(basename "$file") ==="
            cat "$file"
        fi
    done 2>/dev/null

    echo -e "\nТекущее состояние:"
    systemctl status systemd-networkd --no-pager -l | head -20

    read -p "Нажмите Enter для продолжения..."
}

# Функция 11: Сброс всех сетевых настроек
reset_network_default() {
    echo -e "\n${RED}=== СБРОС СЕТЕВЫХ НАСТРОЕК ===${NC}\n"
    
    echo "${RED}ВНИМАНИЕ! Это может прервать SSH соединение!${NC}"
    read -p "Вы уверены? (y/N): " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && return
    
    echo "Сбрасываем настройки..."
    
    # Резервная копия
    backup_dir="/tmp/network_backup_$(date +%s)"
    mkdir -p $backup_dir
    cp -r /etc/netplan/* $backup_dir/ 2>/dev/null
    cp -r $NETWORKD_DIR/* $backup_dir/ 2>/dev/null
    
    # Остановка служб
    systemctl stop isc-dhcp-server 2>/dev/null
    systemctl stop dnsmasq 2>/dev/null
    
    # Очистка конфигов
    rm -f /etc/netplan/*.yaml 2>/dev/null
    rm -f $NETWORKD_DIR/* 2>/dev/null
    
    # Сброс интерфейсов
    for iface in $(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo); do
        ip addr flush dev $iface 2>/dev/null
        ip link set $iface down 2>/dev/null
        ip link set $iface up 2>/dev/null
        dhclient -r $iface 2>/dev/null
    done
    
    # Базовая конфигурация DHCP
    cat > /etc/netplan/00-default.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: yes
EOF
    
    netplan apply
    
    echo "Сброс завершен. Резервная копия в $backup_dir"
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 12: Резервное копирование
backup_configs() {
    echo -e "\n${GREEN}=== РЕЗЕРВНОЕ КОПИРОВАНИЕ ===${NC}\n"
    
    backup_dir="/root/network_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $backup_dir
    
    echo "Создаем резервную копию..."
    
    # Копируем файлы
    cp -r /etc/netplan/ $backup_dir/ 2>/dev/null
    cp -r $NETWORKD_DIR/ $backup_dir/ 2>/dev/null
    cp /etc/dhcp/dhcpd.conf $backup_dir/ 2>/dev/null
    cp /etc/dnsmasq.conf $backup_dir/ 2>/dev/null
    cp /etc/default/isc-dhcp-server $backup_dir/ 2>/dev/null
    
    # Состояние сети
    ip addr show > $backup_dir/ip_addr.txt 2>/dev/null
    ip route show > $backup_dir/ip_route.txt 2>/dev/null
    
    echo "Резервная копия создана: $backup_dir"
    ls -la $backup_dir/
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 13: Восстановление из резервной копии
restore_backup() {
    echo -e "\n${GREEN}=== ВОССТАНОВЛЕНИЕ ===${NC}\n"
    
    echo "Доступные резервные копии:"
    find /root -name "network_backup_*" -type d 2>/dev/null | head -5
    
    read -p "Введите путь к резервной копии: " backup_path
    [[ ! -d $backup_path ]] && echo "Директория не найдена" && return
    
    read -p "Восстановить? (y/N): " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && return
    
    # Восстановление
    cp -r $backup_path/netplan/* /etc/netplan/ 2>/dev/null
    cp -r $backup_path/network/* $NETWORKD_DIR/ 2>/dev/null
    cp $backup_path/dhcpd.conf /etc/dhcp/ 2>/dev/null
    cp $backup_path/dnsmasq.conf /etc/ 2>/dev/null
    cp $backup_path/isc-dhcp-server /etc/default/ 2>/dev/null
    
    netplan apply
    systemctl restart systemd-networkd 2>/dev/null
    
    echo "Восстановление завершено"
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 14: Установка DHCP сервера
install_dhcp_server() {
    echo -e "\n${GREEN}=== УСТАНОВКА DHCP СЕРВЕРА ===${NC}\n"
    
    echo "1. isc-dhcp-server"
    echo "2. dnsmasq"
    echo "3. Удалить все"
    read -p "Выберите опцию [1-3]: " install_option
    
    case $install_option in
        1)
            apt update && apt install -y isc-dhcp-server
            echo "Установлен isc-dhcp-server"
            ;;
        2)
            apt update && apt install -y dnsmasq
            echo "Установлен dnsmasq"
            ;;
        3)
            apt remove -y isc-dhcp-server dnsmasq
            apt autoremove -y
            echo "Удалено"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 15: Перезапуск сетевых служб
restart_network_services() {
    echo -e "\n${GREEN}=== ПЕРЕЗАПУСК СЛУЖБ ===${NC}\n"
    
    echo "1. Все службы"
    echo "2. systemd-networkd"
    echo "3. DHCP серверы"
    read -p "Выберите опцию [1-3]: " restart_option
    
    case $restart_option in
        1)
            systemctl restart systemd-networkd
            systemctl restart isc-dhcp-server 2>/dev/null
            systemctl restart dnsmasq 2>/dev/null
            echo "Все службы перезапущены"
            ;;
        2)
            systemctl restart systemd-networkd
            echo "systemd-networkd перезапущен"
            ;;
        3)
            systemctl restart isc-dhcp-server 2>/dev/null
            systemctl restart dnsmasq 2>/dev/null
            echo "DHCP серверы перезапущены"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 16: Настроить статический IP
setup_static_ip() {
    echo -e "\n${GREEN}=== НАСТРОЙКА СТАТИЧЕСКОГО IP ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    read -p "Введите IP адрес [192.168.10.1]: " static_ip
    static_ip=${static_ip:-"192.168.10.1"}
    
    read -p "Введите маску [24]: " netmask
    netmask=${netmask:-"24"}
    
    read -p "Введите шлюз [$static_ip]: " gateway
    gateway=${gateway:-$static_ip}
    
    read -p "Введите DNS [8.8.8.8]: " dns
    dns=${dns:-"8.8.8.8"}
    
    config_file="/etc/netplan/99-static-$interface.yaml"
    
    cat > $config_file << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses:
        - $static_ip/$netmask
      routes:
        - to: default
          via: $gateway
      nameservers:
        addresses: [$dns]
EOF
    
    netplan apply
    
    echo "Настройки применены"
    ip addr show $interface
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 17: Показать текущую конфигурацию сети
show_network_config() {
    echo -e "\n${GREEN}=== ТЕКУЩАЯ КОНФИГУРАЦИЯ ===${NC}\n"
    
    echo "1. Интерфейсы"
    ip -brief addr show
    
    echo -e "\n2. Маршруты"
    ip route show
    
    echo -e "\n3. Netplan файлы"
    ls -la /etc/netplan/ 2>/dev/null || echo "Нет файлов"
    
    echo -e "\n4. systemd-networkd файлы"
    ls -la $NETWORKD_DIR/ 2>/dev/null || echo "Нет файлов"
    
    echo -e "\n5. DNS"
    cat /etc/resolv.conf 2>/dev/null || echo "Не найден"
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 18: Тестирование соединения
test_connectivity() {
    echo -e "\n${GREEN}=== ТЕСТИРОВАНИЕ ===${NC}\n"
    
    echo "1. Локальный интерфейс"
    echo "2. Шлюз"
    echo "3. Интернет"
    echo "4. DNS"
    read -p "Выберите опцию [1-4]: " test_option
    
    case $test_option in
        1)
            ping -c 2 127.0.0.1 && echo "Локальный OK" || echo "Локальный ERROR"
            ;;
        2)
            gateway=$(ip route show default | awk '/default/ {print $3}')
            if [[ -n $gateway ]]; then
                ping -c 2 $gateway && echo "Шлюз OK" || echo "Шлюз ERROR"
            else
                echo "Шлюз не найден"
            fi
            ;;
        3)
            ping -c 2 8.8.8.8 && echo "Интернет OK" || echo "Интернет ERROR"
            ;;
        4)
            nslookup google.com 8.8.8.8 2>/dev/null && echo "DNS OK" || echo "DNS ERROR"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 19: Управление IP Forwarding
manage_ip_forwarding() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ IP FORWARDING ===${NC}\n"

    # Показать текущее состояние
    current_state=$(sysctl -n net.ipv4.ip_forward)
    if [ "$current_state" -eq 1 ]; then
        echo -e "Текущее состояние: ${GREEN}ВКЛЮЧЕНО${NC}"
    else
        echo -e "Текущее состояние: ${RED}ВЫКЛЮЧЕНО${NC}"
    fi

    echo -e "\n${YELLOW}Опции:${NC}"
    echo "1. Включить IP Forwarding"
    echo "2. Выключить IP Forwarding"
    echo "3. Включить с сохранением в sysctl.conf"
    echo "4. Настроить NAT (маскарадинг)"
    echo "5. Показать правила iptables для forward"
    read -p "Выберите опцию [1-5]: " forward_option

    case $forward_option in
        1)
            # Включить временно
            echo "Включаем IP Forwarding..."
            sysctl -w net.ipv4.ip_forward=1
            echo -e "${GREEN}IP Forwarding включен (временно)${NC}"
            ;;
        2)
            # Выключить
            echo "Выключаем IP Forwarding..."
            sysctl -w net.ipv4.ip_forward=0
            echo -e "${YELLOW}IP Forwarding выключен${NC}"
            ;;
        3)
            # Включить с сохранением
            echo "Включаем IP Forwarding с сохранением..."
            sysctl -w net.ipv4.ip_forward=1

            # Проверяем, есть ли уже настройка в sysctl.conf
            if grep -q "net.ipv4.ip_forward" /etc/sysctl.conf; then
                sed -i 's/^#*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
            else
                echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
            fi

            # Применяем настройки
            sysctl -p
            echo -e "${GREEN}IP Forwarding включен и сохранен в /etc/sysctl.conf${NC}"
            ;;
        4)
            # Настроить NAT (маскарадинг)
            read -p "Введите имя внутреннего интерфейса [$DEFAULT_INTERFACE]: " internal_if
            internal_if=${internal_if:-$DEFAULT_INTERFACE}

            read -p "Введите имя внешнего интерфейса (обычно eth0, enp0s3): " external_if
            if [ -z "$external_if" ]; then
                # Автоматическое определение внешнего интерфейса с маршрутом по умолчанию
                external_if=$(ip route show default | awk '/default/ {print $5}')
                if [ -z "$external_if" ]; then
                    echo -e "${RED}Не удалось определить внешний интерфейс${NC}"
                    return
                fi
                echo "Автоопределение: внешний интерфейс - $external_if"
            fi

            echo -e "\n${YELLOW}Настраиваем NAT (маскарадинг)...${NC}"

            # Включаем IP forwarding
            sysctl -w net.ipv4.ip_forward=1

            # Проверяем наличие правила MASQUERADE
            if ! iptables -t nat -C POSTROUTING -o $external_if -j MASQUERADE 2>/dev/null; then
                # Добавляем правило
                iptables -t nat -A POSTROUTING -o $external_if -j MASQUERADE
                echo -e "${GREEN}Правило MASQUERADE добавлено для интерфейса $external_if${NC}"
            else
                echo -e "${YELLOW}Правило MASQUERADE уже существует${NC}"
            fi

            # Разрешаем forward между интерфейсами
            iptables -A FORWARD -i $internal_if -o $external_if -j ACCEPT
            iptables -A FORWARD -i $external_if -o $internal_if -m state --state RELATED,ESTABLISHED -j ACCEPT

            echo -e "${GREEN}Правила forward настроены${NC}"
            echo -e "\n${YELLOW}Проверка:${NC}"
            iptables -t nat -L POSTROUTING -v
            ;;
        5)
            # Показать правила forward
            echo -e "\n${YELLOW}Правила NAT (таблица nat):${NC}"
            iptables -t nat -L -v -n

            echo -e "\n${YELLOW}Правила FORWARD (таблица filter):${NC}"
            iptables -L FORWARD -v -n

            echo -e "\n${YELLOW}Текущее состояние IP Forwarding:${NC}"
            sysctl net.ipv4.ip_forward
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    read -p "Нажмите Enter для продолжения..."
}

# Функция 20: Управление UFW
manage_ufw() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ UFW (БРАНДМАУЭР) ===${NC}\n"

    # Проверяем и устанавливаем UFW при необходимости
    check_install_ufw || return

    # Показываем статус
    echo -e "${YELLOW}Текущий статус UFW:${NC}"
    ufw status verbose

    echo -e "\n${YELLOW}Опции:${NC}"
    echo "1. Включить UFW"
    echo "2. Выключить UFW"
    echo "3. Разрешить порт"
    echo "4. Запретить порт"
    echo "5. Разрешить службу"
    echo "6. Сбросить все правила"
    echo "7. Разрешить SSH (обязательно перед включением!)"
    echo "8. Разрешить доступ к DHCP серверу (порты 67/68)"
    echo "9. Показать все правила"
    echo "10. Настроить правила для интерфейсов"
    read -p "Выберите опцию [1-10]: " ufw_option

    case $ufw_option in
        1)
            echo "Включаем UFW..."
            ufw --force enable
            echo -e "${GREEN}UFW включен${NC}"
            ;;
        2)
            echo "Выключаем UFW..."
            ufw disable
            echo -e "${YELLOW}UFW выключен${NC}"
            ;;
        3)
            read -p "Введите порт (например: 80, 22/tcp): " port
            if [ -n "$port" ]; then
                ufw allow $port
                echo -e "${GREEN}Порт $port разрешен${NC}"
            fi
            ;;
        4)
            read -p "Введите порт (например: 80, 22/tcp): " port
            if [ -n "$port" ]; then
                ufw deny $port
                echo -e "${RED}Порт $port запрещен${NC}"
            fi
            ;;
        5)
            echo "Доступные службы:"
            ufw app list
            read -p "Введите имя службы: " service
            if [ -n "$service" ]; then
                ufw allow "$service"
                echo -e "${GREEN}Служба $service разрешена${NC}"
            fi
            ;;
        6)
            read -p "Вы уверены, что хотите сбросить все правила? (y/N): " confirm
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                ufw --force reset
                echo -e "${YELLOW}Все правила UFW сброшены${NC}"
            fi
            ;;
        7)
            echo "Разрешаем SSH..."
            ufw allow ssh
            ufw allow 22/tcp
            echo -e "${GREEN}SSH разрешен${NC}"
            echo -e "${YELLOW}ВАЖНО: Убедитесь, что SSH доступен перед включением UFW!${NC}"
            ;;
        8)
            echo "Разрешаем доступ к DHCP серверу..."
            ufw allow 67/udp
            ufw allow 68/udp
            echo -e "${GREEN}Порты DHCP (67/68 UDP) разрешены${NC}"
            ;;
        9)
            echo -e "\n${YELLOW}Все правила UFW:${NC}"
            ufw status numbered
            ;;
        10)
            read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
            interface=${interface:-$DEFAULT_INTERFACE}

            echo -e "\n${YELLOW}Настройка правил для интерфейса $interface:${NC}"
            echo "1. Разрешить весь трафик на интерфейсе"
            echo "2. Разрешить только определенные порты"
            echo "3. Запретить весь входящий трафик на интерфейсе"
            read -p "Выберите опцию [1-3]: " if_option

            case $if_option in
                1)
                    ufw allow in on $interface
                    echo -e "${GREEN}Весь трафик на $interface разрешен${NC}"
                    ;;
                2)
                    read -p "Введите порты через запятую (например: 80,443,22): " ports
                    IFS=',' read -ra port_array <<< "$ports"
                    for port in "${port_array[@]}"; do
                        port=$(echo $port | xargs)  # Удаляем пробелы
                        ufw allow in on $interface to any port $port
                        echo "Порт $port на $interface разрешен"
                    done
                    ;;
                3)
                    ufw deny in on $interface
                    echo -e "${RED}Весь входящий трафик на $interface запрещен${NC}"
                    ;;
                *)
                    echo "Неверный выбор"
                    ;;
            esac
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    read -p "Нажмите Enter для продолжения..."
}

# Функция 21: Управление iptables
manage_iptables() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ IPTABLES ===${NC}\n"

    # Проверяем установлен ли iptables
    if ! command -v iptables &> /dev/null; then
        echo -e "${YELLOW}iptables не установлен. Устанавливаем...${NC}"
        apt update && apt install -y iptables iptables-persistent
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}iptables успешно установлен${NC}"
        else
            echo -e "${RED}Ошибка установки iptables${NC}"
            return
        fi
    fi

    echo -e "${YELLOW}Опции:${NC}"
    echo "1. Показать все правила"
    echo "2. Сохранить правила в файл"
    echo "3. Восстановить правила из файла"
    echo "4. Сбросить все правила"
    echo "5. Сохранить правила для автоматической загрузки"
    echo "6. Добавить правило для DHCP"
    echo "7. Добавить правило для NAT"
    echo "8. Настроить базовые правила"
    echo "9. Показать правила по цепочкам"
    echo "10. Экспорт всех правил"
    read -p "Выберите опцию [1-10]: " iptables_option

    case $iptables_option in
        1)
            echo -e "\n${YELLOW}Все правила iptables:${NC}"
            iptables -L -v -n --line-numbers
            echo -e "\n${YELLOW}Правила NAT:${NC}"
            iptables -t nat -L -v -n --line-numbers
            ;;
        2)
            read -p "Введите путь для сохранения [$IPTABLES_BACKUP]: " backup_file
            backup_file=${backup_file:-$IPTABLES_BACKUP}

            # Сохраняем правила IPv4
            iptables-save > $backup_file
            # Сохраняем правила IPv6
            ip6tables-save > "${backup_file}.ipv6"

            echo -e "${GREEN}Правила сохранены в:${NC}"
            echo "IPv4: $backup_file"
            echo "IPv6: ${backup_file}.ipv6"
            ;;
        3)
            echo "Доступные файлы резервных копий:"
            find /root -name "*iptables*backup*" -type f 2>/dev/null | head -5

            read -p "Введите путь к файлу резервной копии: " restore_file
            if [ -f "$restore_file" ]; then
                echo "Восстанавливаем правила..."
                iptables-restore < $restore_file
                echo -e "${GREEN}Правила восстановлены из $restore_file${NC}"
            else
                echo -e "${RED}Файл не найден${NC}"
            fi
            ;;
        4)
            read -p "Вы уверены, что хотите сбросить ВСЕ правила iptables? (y/N): " confirm
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                echo "Сбрасываем правила..."
                iptables -F
                iptables -X
                iptables -t nat -F
                iptables -t nat -X
                iptables -t mangle -F
                iptables -t mangle -X
                iptables -t raw -F
                iptables -t raw -X
                iptables -P INPUT ACCEPT
                iptables -P FORWARD ACCEPT
                iptables -P OUTPUT ACCEPT
                echo -e "${YELLOW}Все правила iptables сброшены${NC}"
            fi
            ;;
        5)
            echo "Сохраняем правила для автоматической загрузки..."
            if command -v iptables-persistent &> /dev/null; then
                netfilter-persistent save
                echo -e "${GREEN}Правила сохранены для автоматической загрузки${NC}"
            else
                echo -e "${YELLOW}iptables-persistent не установлен${NC}"
                echo "Установите: apt install iptables-persistent"
            fi
            ;;
        6)
            # Правила для DHCP сервера
            echo "Добавляем правила для DHCP сервера..."

            # Разрешаем DHCP запросы (UDP 67-68)
            iptables -A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
            iptables -A OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT

            # Разрешаем широковещательные DHCP пакеты
            iptables -A INPUT -p udp --dport 67 -s 0.0.0.0 -j ACCEPT
            iptables -A INPUT -p udp --dport 68 -s 0.0.0.0 -j ACCEPT

            echo -e "${GREEN}Правила для DHCP добавлены${NC}"
            ;;
        7)
            # Правила для NAT
            read -p "Введите внутренний интерфейс [$DEFAULT_INTERFACE]: " internal_if
            internal_if=${internal_if:-$DEFAULT_INTERFACE}

            read -p "Введите внешний интерфейс (обычно с доступом в интернет): " external_if
            if [ -z "$external_if" ]; then
                external_if=$(ip route show default | awk '/default/ {print $5}')
                echo "Автоопределение: внешний интерфейс - $external_if"
            fi

            echo "Добавляем правила NAT..."

            # Включаем IP forwarding
            echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipforward.conf
            sysctl -p /etc/sysctl.d/99-ipforward.conf

            # Добавляем правила MASQUERADE
            iptables -t nat -A POSTROUTING -o $external_if -j MASQUERADE

            # Разрешаем forward трафик
            iptables -A FORWARD -i $internal_if -o $external_if -j ACCEPT
            iptables -A FORWARD -i $external_if -o $internal_if -m state --state RELATED,ESTABLISHED -j ACCEPT

            # Разрешаем входящие соединения для внутренней сети
            iptables -A INPUT -i $internal_if -j ACCEPT

            echo -e "${GREEN}Правила NAT настроены для интерфейсов:${NC}"
            echo "Внутренний: $internal_if"
            echo "Внешний: $external_if"
            ;;
        8)
            # Базовые правила безопасности
            echo "Настраиваем базовые правила безопасности..."

            # Устанавливаем политики по умолчанию
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT

            # Разрешаем loopback
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT

            # Разрешаем установленные и связанные соединения
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

            # Разрешаем SSH (изменяйте порт при необходимости)
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT

            # Разрешаем ping
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

            # Разрешаем DHCP
            iptables -A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT

            echo -e "${GREEN}Базовые правила безопасности настроены${NC}"
            echo -e "${YELLOW}ВНИМАНИЕ: Проверьте доступность SSH перед применением!${NC}"
            ;;
        9)
            # Показать правила по цепочкам
            echo -e "\n${YELLOW}Цепочка INPUT:${NC}"
            iptables -L INPUT -v -n --line-numbers

            echo -e "\n${YELLOW}Цепочка FORWARD:${NC}"
            iptables -L FORWARD -v -n --line-numbers

            echo -e "\n${YELLOW}Цепочка OUTPUT:${NC}"
            iptables -L OUTPUT -v -n --line-numbers

            echo -e "\n${YELLOW}Цепочка POSTROUTING (NAT):${NC}"
            iptables -t nat -L POSTROUTING -v -n --line-numbers
            ;;
        10)
            # Экспорт всех правил
            export_file="/root/iptables_export_$(date +%Y%m%d_%H%M%S).sh"

            echo "#!/bin/bash" > $export_file
            echo "# Экспорт правил iptables" >> $export_file
            echo "# Создан: $(date)" >> $export_file
            echo "" >> $export_file
            echo "# Сброс всех правил" >> $export_file
            echo "iptables -F" >> $export_file
            echo "iptables -X" >> $export_file
            echo "iptables -t nat -F" >> $export_file
            echo "iptables -t nat -X" >> $export_file
            echo "iptables -t mangle -F" >> $export_file
            echo "iptables -t mangle -X" >> $export_file
            echo "iptables -t raw -F" >> $export_file
            echo "iptables -t raw -X" >> $export_file
            echo "" >> $export_file
            echo "# Политики по умолчанию" >> $export_file
            echo "iptables -P INPUT ACCEPT" >> $export_file
            echo "iptables -P FORWARD ACCEPT" >> $export_file
            echo "iptables -P OUTPUT ACCEPT" >> $export_file
            echo "" >> $export_file

            # Получаем и добавляем правила
            iptables-save | grep -v "^#" | grep -v "^COMMIT" | while read rule; do
                if [[ -n $rule ]]; then
                    echo "iptables $rule" >> $export_file
                fi
            done

            echo "" >> $export_file
            echo "# Сохранение правил" >> $export_file
            echo "iptables-save > /etc/iptables/rules.v4" >> $export_file
            echo "ip6tables-save > /etc/iptables/rules.v6" >> $export_file

            chmod +x $export_file

            echo -e "${GREEN}Правила экспортированы в: $export_file${NC}"
            echo "Вы можете выполнить этот скрипт для восстановления правил."
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    read -p "Нажмите Enter для продолжения..."
}

# Основной цикл
main() {
    check_root

    while true; do
        show_menu
        read choice

        case $choice in
            1) full_diagnostic ;;
            2) setup_isc_dhcp ;;
            3) setup_dnsmasq ;;
            4) setup_systemd_networkd_dhcp ;;
            5) fix_ip_address ;;
            6) show_dhcp_logs ;;
            7) check_dhcp_clients ;;
            8) monitor_dhcp_traffic ;;
            9) manage_systemd_networkd ;;
            10) view_systemd_networkd_config ;;
            11) reset_network_default ;;
            12) backup_configs ;;
            13) restore_backup ;;
            14) install_dhcp_server ;;
            15) restart_network_services ;;
            16) setup_static_ip ;;
            17) show_network_config ;;
            18) test_connectivity ;;
            19) manage_ip_forwarding ;;
            20) manage_ufw ;;
            21) manage_iptables ;;
            22)
                echo "Выход"
                exit 0
                ;;
            *)
                echo "Неверный выбор"
                sleep 1
                ;;
        esac
    done
}

# Запуск
main
