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
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         DHCP Server Manager - Ubuntu Server 24.04                             ║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} 1.  Полная диагностика сети и DHCP сервера                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 2.  Настроить DHCP сервер (isc-dhcp-server)                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 3.  Настроить DHCP сервер (dnsmasq - проще)                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 4.  Настроить DHCP сервер (systemd-networkd)                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 5.  Проверить и исправить IP адрес на интерфейсе                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 6.  Показать логи DHCP сервера                                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 7.  Проверить клиентов DHCP (аренды)                              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 8.  Мониторинг DHCP трафика в реальном времени                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 9.  Управление systemd-networkd                                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 10. Просмотр конфигурации systemd-networkd                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 11. Сбросить все сетевые настройки по умолчанию                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 12. Резервное копирование сетевых конфигураций                    ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 13. Восстановить из резервной копии                               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 14. Установить/переустановить DHCP сервер                         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 15. Перезапустить сетевые службы                                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 16. Настроить статический IP на интерфейсе                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 17. Показать текущую конфигурацию сети                            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 18. Тестирование соединения                                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 19. Управление IP Forwarding (перенаправление трафика)            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 20. Управление UFW (брандмауэр)                                   ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 21. Управление iptables (правила фаервола)                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 22. Управление маршрутизацией (добавить/удалить маршруты)         ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 23. Управление переименованием сетевых интерфейсов                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 24. Выход                                                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -n "Выберите опцию [1-24]: "
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
    
    echo -e "${YELLOW}Доступные сетевые интерфейсы:${NC}"
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))

    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}Нет доступных сетевых интерфейсов!${NC}"
        return 1
    fi

    # Отображаем список интерфейсов с информацией
    for i in "${!interfaces[@]}"; do
        iface="${interfaces[$i]}"
        status=$(ip link show $iface | grep -o "state [A-Z]*" | cut -d' ' -f2)
        ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        echo "  $((i+1)). $iface [Статус: $status, IP: ${ip_addr:-нет}]"
    done

    # Выбор интерфейса
    while true; do
        echo -e "\n${GREEN}Выберите интерфейс для настройки DHCP:${NC}"
        for i in "${!interfaces[@]}"; do
            echo "  $((i+1)). ${interfaces[$i]}"
        done
        echo "  0. Вручную ввести имя интерфейса"

        read -p "Введите номер [0-${#interfaces[@]}]: " choice

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -eq 0 ]; then
                read -p "Введите имя интерфейса вручную: " interface
                # Проверяем существование введенного интерфейса
                if ip link show "$interface" &>/dev/null; then
                    break
                else
                    echo -e "${RED}Интерфейс '$interface' не найден!${NC}"
                    continue
                fi
            elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#interfaces[@]} ]; then
                interface="${interfaces[$((choice-1))]}"
                break
            else
                echo -e "${RED}Неверный номер! Пожалуйста, выберите от 0 до ${#interfaces[@]}${NC}"
            fi
        else
            echo -e "${RED}Введите число!${NC}"
        fi
    done

    echo -e "\n${GREEN}Выбран интерфейс: $interface${NC}"

    # Показываем текущую конфигурацию интерфейса
    echo -e "\n${YELLOW}Текущая конфигурация $interface:${NC}"
    ip addr show $interface 2>/dev/null | head -20

    read -p "Продолжить с этим интерфейсом? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Отмена настройки.${NC}"
        return 1
    fi
    
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

    # Проверим, какие методы конфигурации доступны
    echo -e "\n${YELLOW}Обнаруженные методы конфигурации:${NC}"
    has_netplan=false
    has_systemd_networkd=false

    if [[ -d "/etc/netplan" ]] && ls /etc/netplan/*.yaml 2>/dev/null >/dev/null; then
        echo "✓ Netplan доступен"
        has_netplan=true
    fi

    if systemctl is-active systemd-networkd >/dev/null 2>&1 && [[ -d "$NETWORKD_DIR" ]]; then
        echo "✓ systemd-networkd доступен"
        has_systemd_networkd=true
    fi

    echo -e "\n${YELLOW}Опции:${NC}"
    echo "1. Назначить статический IP (временно)"
    echo "2. Назначить статический IP (постоянно)"
    echo "3. Включить DHCP (временно)"
    echo "4. Включить DHCP (постоянно)"
    echo "5. Сбросить настройки"
    echo "6. Проверить соединение"
    read -p "Выберите опцию [1-6]: " ip_option

    case $ip_option in
        1)
            # Временный статический IP
            read -p "Введите IP адрес [192.168.10.1]: " static_ip
            static_ip=${static_ip:-"192.168.10.1"}
            read -p "Введите маску подсети [24]: " netmask
            netmask=${netmask:-"24"}

            echo "Назначаем временный статический IP $static_ip/$netmask..."
            ip addr flush dev $interface 2>/dev/null
            ip addr add $static_ip/$netmask dev $interface 2>/dev/null
            ip link set $interface up 2>/dev/null

            echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
            ip addr show $interface
            echo -e "${YELLOW}Внимание: Этот IP будет сброшен после перезагрузки!${NC}"
            ;;

        2)
            # Постоянный статический IP
            read -p "Введите IP адрес [192.168.10.1]: " static_ip
            static_ip=${static_ip:-"192.168.10.1"}
            read -p "Введите маску подсети [24]: " netmask
            netmask=${netmask:-"24"}

            echo -e "\n${YELLOW}Выберите метод сохранения:${NC}"
            if $has_netplan && $has_systemd_networkd; then
                echo "1. Netplan (рекомендуется для Ubuntu)"
                echo "2. systemd-networkd"
                read -p "Выберите [1-2]: " method_choice
            elif $has_netplan; then
                echo "1. Netplan"
                method_choice=1
            elif $has_systemd_networkd; then
                echo "2. systemd-networkd"
                method_choice=2
            else
                echo "Не найдены методы конфигурации. Используем временную настройку."
                method_choice=0
            fi

            case $method_choice in
                1)
                    # Netplan конфигурация
                    echo "Настраиваем через Netplan..."

                    # Создаем или обновляем конфиг netplan
                    netplan_file="/etc/netplan/01-$interface-static.yaml"

                    cat > $netplan_file << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses:
        - $static_ip/$netmask
      dhcp4: no
      dhcp6: no
EOF

                    echo "Применяем настройки Netplan..."
                    netplan apply

                    echo -e "${GREEN}Настройки Netplan сохранены в $netplan_file${NC}"
                    ;;

                2)
                    # systemd-networkd конфигурация
                    echo "Настраиваем через systemd-networkd..."

                    network_file="$NETWORKD_DIR/10-$interface.network"

                    cat > $network_file << EOF
[Match]
Name=$interface

[Network]
Address=$static_ip/$netmask
EOF

                    echo "Перезапускаем systemd-networkd..."
                    systemctl restart systemd-networkd

                    echo -e "${GREEN}Настройки systemd-networkd сохранены в $network_file${NC}"
                    ;;

                *)
                    # Временная настройка как fallback
                    echo "Используем временную настройку..."
                    ip addr flush dev $interface 2>/dev/null
                    ip addr add $static_ip/$netmask dev $interface 2>/dev/null
                    ip link set $interface up 2>/dev/null
                    echo -e "${YELLOW}Настройки временные - не сохранятся после перезагрузки!${NC}"
                    ;;
            esac

            # Применяем временно для немедленного эффекта
            ip addr flush dev $interface 2>/dev/null
            ip addr add $static_ip/$netmask dev $interface 2>/dev/null
            ip link set $interface up 2>/dev/null

            echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
            ip addr show $interface
            ;;

        3)
            # Временный DHCP клиент
            echo "Включаем DHCP временно..."
            dhclient -r $interface 2>/dev/null
            dhclient $interface 2>/dev/null &

            sleep 3
            echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
            ip addr show $interface
            echo -e "${YELLOW}Внимание: Эти настройки будут сброшены после перезагрузки!${NC}"
            ;;

        4)
            # Постоянный DHCP клиент
            echo "Настраиваем постоянный DHCP клиент..."

            echo -e "\n${YELLOW}Выберите метод сохранения:${NC}"
            if $has_netplan && $has_systemd_networkd; then
                echo "1. Netplan (рекомендуется для Ubuntu)"
                echo "2. systemd-networkd"
                read -p "Выберите [1-2]: " method_choice
            elif $has_netplan; then
                echo "1. Netplan"
                method_choice=1
            elif $has_systemd_networkd; then
                echo "2. systemd-networkd"
                method_choice=2
            else
                echo "Не найдены методы конфигурации."
                return 1
            fi

            case $method_choice in
                1)
                    # Netplan DHCP конфигурация
                    netplan_file="/etc/netplan/01-$interface-dhcp.yaml"

                    cat > $netplan_file << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: yes
      dhcp6: no
      optional: true
EOF

                    echo "Применяем настройки Netplan..."
                    netplan apply
                    echo -e "${GREEN}Настройки DHCP через Netplan сохранены${NC}"
                    ;;

                2)
                    # systemd-networkd DHCP конфигурация
                    network_file="$NETWORKD_DIR/10-$interface.network"

                    cat > $network_file << EOF
[Match]
Name=$interface

[Network]
DHCP=yes
EOF

                    echo "Перезапускаем systemd-networkd..."
                    systemctl restart systemd-networkd
                    echo -e "${GREEN}Настройки DHCP через systemd-networkd сохранены${NC}"
                    ;;
            esac

            # Запускаем DHCP клиент для немедленного получения адреса
            dhclient -r $interface 2>/dev/null
            dhclient $interface 2>/dev/null &

            sleep 2
            echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
            ip addr show $interface
            ;;

        5)
            # Сброс настроек
            echo "Сбрасываем настройки интерфейса..."

            # Временный сброс
            ip addr flush dev $interface 2>/dev/null
            ip link set $interface down 2>/dev/null
            sleep 1
            ip link set $interface up 2>/dev/null

            # Удаляем конфигурационные файлы
            echo "Удаляем конфигурационные файлы..."

            # Netplan
            rm -f /etc/netplan/*-$interface-*.yaml 2>/dev/null
            rm -f /etc/netplan/*-$interface.yaml 2>/dev/null

            # systemd-networkd
            rm -f $NETWORKD_DIR/*-$interface.network 2>/dev/null
            rm -f $NETWORKD_DIR/*-$interface.network 2>/dev/null

            # Применяем изменения
            if $has_netplan; then
                netplan apply 2>/dev/null
            fi

            if $has_systemd_networkd; then
                systemctl restart systemd-networkd 2>/dev/null
            fi

            echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
            ip addr show $interface
            echo -e "${GREEN}Все настройки интерфейса сброшены${NC}"
            ;;

        6)
            # Проверка соединения
            echo "Проверяем соединение..."

            # Проверяем физическое соединение
            if command -v ethtool >/dev/null; then
                echo -e "\n${YELLOW}Физическое соединение:${NC}"
                ethtool $interface 2>/dev/null | grep -E "Link|Speed|Duplex" || echo "ethtool не доступен"
            fi

            # Проверяем IP адрес
            echo -e "\n${YELLOW}IP адрес:${NC}"
            ip -4 addr show $interface 2>/dev/null | grep inet || echo "IP адрес не назначен"

            # Проверяем маршруты
            echo -e "\n${YELLOW}Маршруты для интерфейса:${NC}"
            ip route show | grep "dev $interface" || echo "Нет маршрутов через этот интерфейс"

            # Проверяем доступность шлюза
            gateway=$(ip route show default | grep "dev $interface" | awk '{print $3}')
            if [ -n "$gateway" ]; then
                echo -e "\n${YELLOW}Проверка шлюза ($gateway):${NC}"
                ping -c 2 -W 1 $gateway 2>/dev/null && echo "Шлюз доступен" || echo "Шлюз недоступен"
            fi
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

    # Получение списка сетевых интерфейсов
    echo -e "${YELLOW}Доступные сетевые интерфейсы:${NC}"
    interfaces=($(ip link show | awk -F': ' '/^[0-9]+:/{print $2}' | grep -v lo))

    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "Не удалось обнаружить сетевые интерфейсы"
        read -p "Нажмите Enter для продолжения..."
        return
    fi

    # Интерактивный выбор интерфейса
    echo -e "\n${CYAN}Выберите сетевой интерфейс:${NC}"
    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done

    while true; do
        read -p "Введите номер интерфейса [1-${#interfaces[@]}] (по умолчанию 1): " interface_choice
        interface_choice=${interface_choice:-1}

        if [[ "$interface_choice" =~ ^[0-9]+$ ]] && [ "$interface_choice" -ge 1 ] && [ "$interface_choice" -le "${#interfaces[@]}" ]; then
            interface="${interfaces[$((interface_choice-1))]}"
            break
        else
            echo -e "${RED}Неверный выбор. Пожалуйста, введите число от 1 до ${#interfaces[@]}${NC}"
        fi
    done

    echo -e "\n${GREEN}Выбран интерфейс: $interface${NC}"

    # Ввод таймаута
    while true; do
        read -p "Введите время мониторинга в секундах [10-3600] (по умолчанию 60): " timeout_input
        timeout_input=${timeout_input:-60}

        if [[ "$timeout_input" =~ ^[0-9]+$ ]] && [ "$timeout_input" -ge 10 ] && [ "$timeout_input" -le 3600 ]; then
            timeout_value=$timeout_input
            break
        else
            echo -e "${RED}Неверное значение. Пожалуйста, введите число от 10 до 3600${NC}"
        fi
    done

    echo -e "\n${CYAN}Опции мониторинга:${NC}"
    echo "1. Краткий мониторинг"
    echo "2. Подробный мониторинг"
    echo "3. Запись в файл (pcap)"
    echo "4. Постоянный мониторинг (без таймаута)"
    read -p "Выберите опцию [1-4] (по умолчанию 1): " monitor_option
    monitor_option=${monitor_option:-1}

    # Обработчик прерываний
    cleanup() {
        echo -e "\n${YELLOW}\nЗавершение мониторинга...${NC}"
        if [ -n "$tcpdump_pid" ]; then
            kill $tcpdump_pid 2>/dev/null
        fi
        exit 0
    }

    trap cleanup SIGINT SIGTERM

    echo -e "\n${GREEN}Начинаем мониторинг DHCP трафика на интерфейсе $interface...${NC}"
    echo -e "${YELLOW}Таймаут: ${timeout_value} секунд${NC}"
    echo -e "${YELLOW}Для остановки нажмите Ctrl+C${NC}\n"

    case $monitor_option in
        1)
            echo -e "${CYAN}Краткий мониторинг (только заголовки)...${NC}"
            timeout $timeout_value tcpdump -i $interface -n "port 67 or port 68" 2>/dev/null &
            tcpdump_pid=$!
            wait $tcpdump_pid 2>/dev/null
            ;;
        2)
            echo -e "${CYAN}Подробный мониторинг (с содержимым пакетов)...${NC}"
            timeout $timeout_value tcpdump -i $interface -n -X "port 67 or port 68" 2>/dev/null &
            tcpdump_pid=$!
            wait $tcpdump_pid 2>/dev/null
            ;;
        3)
            pcap_file="/tmp/dhcp_capture_$(date +%Y%m%d_%H%M%S).pcap"
            echo -e "${CYAN}Запись в файл: $pcap_file ...${NC}"
            timeout $timeout_value tcpdump -i $interface -n -w $pcap_file "port 67 or port 68" 2>/dev/null &
            tcpdump_pid=$!
            wait $tcpdump_pid 2>/dev/null
            echo -e "${GREEN}Запись завершена. Файл сохранен: $pcap_file${NC}"
            echo -e "${YELLOW}Для просмотра файла используйте: tcpdump -r $pcap_file${NC}"
            ;;
        4)
            echo -e "${CYAN}Постоянный мониторинг (без ограничения времени)...${NC}"
            echo -e "${RED}Внимание: Этот режим будет работать до ручной остановки (Ctrl+C)${NC}"
            tcpdump -i $interface -n "port 67 or port 68" 2>/dev/null &
            tcpdump_pid=$!
            wait $tcpdump_pid 2>/dev/null
            ;;
        *)
            echo -e "${RED}Неверный выбор${NC}"
            ;;
    esac

    # Сброс обработчика прерываний
    trap - SIGINT SIGTERM

    echo -e "\n${GREEN}Мониторинг завершен${NC}"
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

            # Проверяем наличие пакета iptables-persistent
            if dpkg -l | grep -q "iptables-persistent"; then
                echo -e "${GREEN}Пакет iptables-persistent установлен${NC}"

                # Пробуем разные методы сохранения
                if command -v netfilter-persistent &> /dev/null; then
                    netfilter-persistent save
                    echo -e "${GREEN}Правила сохранены через netfilter-persistent${NC}"
                elif command -v iptables-persistent &> /dev/null; then
                    iptables-persistent save
                    echo -e "${GREEN}Правила сохранены через iptables-persistent${NC}"
                else
                    # Альтернативный способ сохранения
                    echo "Сохраняем правила вручную..."
                    mkdir -p /etc/iptables
                    iptables-save > /etc/iptables/rules.v4
                    ip6tables-save > /etc/iptables/rules.v6
                    echo -e "${GREEN}Правила сохранены в /etc/iptables/${NC}"
                fi

                # Показываем статус службы
                echo -e "\n${YELLOW}Статус службы:${NC}"
                if systemctl list-unit-files | grep -q netfilter-persistent; then
                    systemctl status netfilter-persistent --no-pager -l
                fi
            else
                echo -e "${YELLOW}Пакет iptables-persistent не установлен${NC}"
                read -p "Установить iptables-persistent? (y/N): " install_confirm
                if [[ $install_confirm == "y" || $install_confirm == "Y" ]]; then
                    apt update && apt install -y iptables-persistent
                    if [ $? -eq 0 ]; then
                        echo -e "${GREEN}Пакет установлен. Сохраняем правила...${NC}"
                        # Сохраняем текущие правила
                        mkdir -p /etc/iptables
                        iptables-save > /etc/iptables/rules.v4
                        ip6tables-save > /etc/iptables/rules.v6
                        echo -e "${GREEN}Правила сохранены для автоматической загрузки${NC}"
                    else
                        echo -e "${RED}Ошибка установки iptables-persistent${NC}"
                    fi
                fi
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

            # Получаем список активных сетевых интерфейсов
            echo -e "${YELLOW}Доступные сетевые интерфейсы:${NC}"
            echo "----------------------------------------"
            ip -o link show | awk -F': ' '{print $2}' | while read iface; do
                ip_addr=$(ip -4 addr show $iface 2>/dev/null | awk '/inet/ {print $2}' | head -1)
                mac_addr=$(ip link show $iface | awk '/link\/ether/ {print $2}' | head -1)
                status=$(ip link show $iface | grep -q 'state UP' && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")

                if [ -n "$ip_addr" ]; then
                    echo -e "  $iface \t| $ip_addr \t| $mac_addr \t| $status"
                else
                    echo -e "  $iface \t| Нет IPv4 \t| $mac_addr \t| $status"
                fi
            done
            echo "----------------------------------------"

            # Выбор внутреннего интерфейса
            echo ""
            read -p "Введите внутренний интерфейс [$DEFAULT_INTERFACE]: " internal_if
            internal_if=${internal_if:-$DEFAULT_INTERFACE}

            # Проверка существования интерфейса
            while ! ip link show $internal_if >/dev/null 2>&1; do
                echo -e "${RED}Ошибка: интерфейс $internal_if не существует!${NC}"
                read -p "Введите корректное имя внутреннего интерфейса: " internal_if
            done

            # Выбор внешнего интерфейса
            echo ""
            read -p "Введите внешний интерфейс (обычно с доступом в интернет) или нажмите Enter для автоопределения: " external_if

            if [ -z "$external_if" ]; then
                # Автоопределение шлюза по умолчанию
                external_if=$(ip route show default | awk '/default/ {print $5}')

                # Если не удалось автоопределить, запросить вручную
                if [ -z "$external_if" ]; then
                    echo -e "${YELLOW}Не удалось автоопределить внешний интерфейс.${NC}"
                    read -p "Введите внешний интерфейс вручную: " external_if
                else
                    echo -e "${GREEN}Автоопределение: внешний интерфейс - $external_if${NC}"
                fi
            fi

            # Проверка существования внешнего интерфейса
            while ! ip link show $external_if >/dev/null 2>&1; do
                echo -e "${RED}Ошибка: интерфейс $external_if не существует!${NC}"
                read -p "Введите корректное имя внешнего интерфейса: " external_if
            done

            # Проверка, что интерфейсы разные
            if [ "$internal_if" = "$external_if" ]; then
                echo -e "${RED}Ошибка: внутренний и внешний интерфейсы не могут быть одинаковыми!${NC}"
                read -p "Хотите изменить выбор? (y/N): " change_choice
                if [[ $change_choice =~ ^[Yy]$ ]]; then
                    read -p "Введите внутренний интерфейс: " internal_if
                    read -p "Введите внешний интерфейс: " external_if
                fi
            fi

            # Подтверждение выбора
            echo ""
            echo -e "${YELLOW}Подтвердите выбор интерфейсов:${NC}"
            echo "Внутренний интерфейс: $internal_if"
            echo "Внешний интерфейс: $external_if"
            read -p "Продолжить настройку? (Y/n): " confirm
            [[ $confirm =~ ^[Nn]$ ]] && continue

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

# Функция 22: Управление маршрутизацией
manage_routing() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ МАРШРУТИЗАЦИЕЙ ===${NC}\n"

    echo -e "${YELLOW}Текущая таблица маршрутизации:${NC}"
    echo "══════════════════════════════════════════"
    ip -c route show
    echo ""

    # Показать доступные интерфейсы
    echo -e "${YELLOW}Доступные сетевые интерфейсы:${NC}"
    echo "══════════════════════════════════════════"
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v lo))

    for i in "${!interfaces[@]}"; do
        iface="${interfaces[$i]}"
        ip_addr=$(ip -4 addr show $iface 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        status=$(ip link show $iface | grep -q "state UP" && echo -e "${GREEN}UP${NC}" || echo -e "${RED}DOWN${NC}")
        echo "  $((i+1)). $iface [IP: ${ip_addr:-нет}, Статус: $status]"
    done
    echo ""

    echo -e "${YELLOW}Опции управления маршрутизацией:${NC}"
    echo "1. Добавить маршрут по умолчанию (шлюз)"
    echo "2. Добавить статический маршрут к сети"
    echo "3. Удалить маршрут"
    echo "4. Показать подробную таблицу маршрутизации"
    echo "5. Очистить все статические маршруты"
    echo "6. Настроить маршрут через systemd-networkd"
    echo "7. Проверить маршрут до хоста"
    read -p "Выберите опцию [1-7]: " routing_option

    case $routing_option in
        1)
            # Добавить маршрут по умолчанию
            echo -e "\n${YELLOW}Добавление маршрута по умолчанию:${NC}"

            # Выбор интерфейса
            if [ ${#interfaces[@]} -eq 0 ]; then
                echo -e "${RED}Нет доступных интерфейсов!${NC}"
                return 1
            fi

            echo "Выберите интерфейс для маршрута по умолчанию:"
            for i in "${!interfaces[@]}"; do
                echo "  $((i+1)). ${interfaces[$i]}"
            done
            echo "  0. Ввести вручную"

            read -p "Выберите номер [0-${#interfaces[@]}]: " iface_choice

            if [[ "$iface_choice" =~ ^[0-9]+$ ]]; then
                if [ "$iface_choice" -eq 0 ]; then
                    read -p "Введите имя интерфейса: " gateway_iface
                elif [ "$iface_choice" -ge 1 ] && [ "$iface_choice" -le ${#interfaces[@]} ]; then
                    gateway_iface="${interfaces[$((iface_choice-1))]}"
                else
                    echo -e "${RED}Неверный номер!${NC}"
                    return 1
                fi
            fi

            # Получаем текущий IP на интерфейсе для подсказки шлюза
            current_ip=$(ip -4 addr show $gateway_iface 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
            if [ -n "$current_ip" ]; then
                gateway_hint=$(echo $current_ip | sed 's/\.[0-9]*$/.1/')
                echo "Текущий IP на $gateway_iface: $current_ip"
                echo "Предполагаемый шлюз: $gateway_hint"
            fi

            read -p "Введите IP адрес шлюза: " gateway_ip
            if [ -z "$gateway_ip" ]; then
                echo -e "${RED}Шлюз не указан!${NC}"
                return 1
            fi

            # Проверяем существующий маршрут по умолчанию
            existing_default=$(ip route show default 2>/dev/null)
            if [ -n "$existing_default" ]; then
                echo -e "${YELLOW}Существующий маршрут по умолчанию:${NC}"
                echo "$existing_default"
                read -p "Заменить его? (y/N): " replace_conf
                if [[ "$replace_conf" =~ ^[Yy]$ ]]; then
                    ip route del default 2>/dev/null
                fi
            fi

            # Добавляем маршрут
            echo "Добавляем маршрут: default via $gateway_ip dev $gateway_iface"
            ip route add default via $gateway_ip dev $gateway_iface

            # Проверяем
            if ip route show default | grep -q "$gateway_iface"; then
                echo -e "${GREEN}Маршрут по умолчанию добавлен успешно!${NC}"
            else
                echo -e "${RED}Ошибка добавления маршрута!${NC}"
            fi
            ;;

        2)
            # Добавить статический маршрут к сети
            echo -e "\n${YELLOW}Добавление статического маршрута:${NC}"

            read -p "Введите сеть назначения (например: 192.168.2.0/24): " dest_network
            if [ -z "$dest_network" ]; then
                echo -e "${RED}Сеть не указана!${NC}"
                return 1
            fi

            echo "Выберите способ указания шлюза:"
            echo "1. Через IP адрес шлюза"
            echo "2. Через интерфейс (для подключенных сетей)"
            read -p "Выберите [1-2]: " gw_method

            case $gw_method in
                1)
                    read -p "Введите IP адрес шлюза: " gateway_ip
                    if [ -z "$gateway_ip" ]; then
                        echo -e "${RED}Шлюз не указан!${NC}"
                        return 1
                    fi

                    # Добавляем маршрут через шлюз
                    echo "Добавляем маршрут: $dest_network via $gateway_ip"
                    ip route add $dest_network via $gateway_ip

                    if ip route show | grep -q "$dest_network"; then
                        echo -e "${GREEN}Маршрут добавлен успешно!${NC}"
                    else
                        echo -e "${RED}Ошибка добавления маршрута!${NC}"
                    fi
                    ;;

                2)
                    # Выбор интерфейса
                    echo "Выберите интерфейс для маршрута:"
                    for i in "${!interfaces[@]}"; do
                        echo "  $((i+1)). ${interfaces[$i]}"
                    done
                    echo "  0. Ввести вручную"

                    read -p "Выберите номер [0-${#interfaces[@]}]: " iface_choice

                    if [[ "$iface_choice" =~ ^[0-9]+$ ]]; then
                        if [ "$iface_choice" -eq 0 ]; then
                            read -p "Введите имя интерфейса: " route_iface
                        elif [ "$iface_choice" -ge 1 ] && [ "$iface_choice" -le ${#interfaces[@]} ]; then
                            route_iface="${interfaces[$((iface_choice-1))]}"
                        else
                            echo -e "${RED}Неверный номер!${NC}"
                            return 1
                        fi
                    fi

                    # Добавляем маршрут через интерфейс
                    echo "Добавляем маршрут: $dest_network dev $route_iface"
                    ip route add $dest_network dev $route_iface

                    if ip route show | grep -q "$dest_network.*dev $route_iface"; then
                        echo -e "${GREEN}Маршрут добавлен успешно!${NC}"
                    else
                        echo -e "${RED}Ошибка добавления маршрута!${NC}"
                    fi
                    ;;

                *)
                    echo "Неверный выбор"
                    return 1
                    ;;
            esac
            ;;

        3)
            # Удалить маршрут
            echo -e "\n${YELLOW}Удаление маршрута:${NC}"

            echo "Текущие маршруты:"
            ip route show | grep -v "^default" | cat -n

            read -p "Введите номер маршрута для удаления: " route_num
            route_to_delete=$(ip route show | grep -v "^default" | sed -n "${route_num}p")

            if [ -z "$route_to_delete" ]; then
                echo -e "${RED}Маршрут не найден!${NC}"
                return 1
            fi

            echo "Удаляем маршрут: $route_to_delete"
            read -p "Вы уверены? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                ip route del $route_to_delete
                echo -e "${GREEN}Маршрут удален!${NC}"
            fi
            ;;

        4)
            # Подробная таблица маршрутизации
            echo -e "\n${YELLOW}Подробная таблица маршрутизации:${NC}"
            echo "══════════════════════════════════════════"
            ip route show table all 2>/dev/null || ip route show
            echo ""

            # Показать таблицу ARP
            echo -e "${YELLOW}ARP таблица:${NC}"
            echo "══════════════════════════════════════════"
            ip neigh show
            ;;

        5)
            # Очистить все статические маршруты
            echo -e "\n${RED}Очистка всех статических маршрутов:${NC}"
            read -p "Вы уверены, что хотите удалить ВСЕ статические маршруты? (y/N): " confirm

            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # Сохраняем только маршрут по умолчанию и подключенные сети
                default_route=$(ip route show default 2>/dev/null)
                connected_routes=$(ip route show | grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+ dev " | awk '{print $1}')

                # Удаляем все маршруты кроме подключенных сетей
                ip route show | grep -v "^default" | grep -v -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+ dev " | while read route; do
                    ip route del $route 2>/dev/null
                done

                echo -e "${GREEN}Статические маршруты очищены!${NC}"
                echo "Сохранены:"
                echo "  - Маршрут по умолчанию: ${default_route:-нет}"
                echo "  - Подключенные сети: $(echo $connected_routes | wc -w) сетей"
            fi
            ;;

        6)
            # Настроить маршрут через systemd-networkd
            echo -e "\n${YELLOW}Настройка маршрута через systemd-networkd:${NC}"

            if [ ! -d "$NETWORKD_DIR" ]; then
                echo -e "${RED}Директория systemd-networkd не найдена!${NC}"
                return 1
            fi

            # Выбор интерфейса
            echo "Выберите интерфейс для настройки:"
            for i in "${!interfaces[@]}"; do
                echo "  $((i+1)). ${interfaces[$i]}"
            done

            read -p "Выберите номер [1-${#interfaces[@]}]: " iface_choice
            if [ "$iface_choice" -ge 1 ] && [ "$iface_choice" -le ${#interfaces[@]} ]; then
                network_iface="${interfaces[$((iface_choice-1))]}"

                # Проверяем существующий конфиг
                network_file="$NETWORKD_DIR/10-$network_iface.network"
                if [ -f "$network_file" ]; then
                    echo -e "${YELLOW}Текущий конфиг $network_file:${NC}"
                    cat "$network_file"
                    read -p "Перезаписать? (y/N): " overwrite
                    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                        echo "Отмена"
                        return 1
                    fi
                fi

                # Настройка маршрутов
                echo -e "\nНастройка маршрутов для $network_iface:"
                echo "1. Только маршрут по умолчанию"
                echo "2. Маршрут по умолчанию + статические маршруты"
                echo "3. Только статические маршруты (без default)"
                read -p "Выберите [1-3]: " route_type

                read -p "Введите IP адрес шлюза для default маршрута: " sysd_gateway

                # Собираем статические маршруты
                routes=""
                if [[ "$route_type" =~ ^[23]$ ]]; then
                    echo "Введите статические маршруты (оставьте пустым для завершения):"
                    route_count=0
                    while true; do
                        read -p "Маршрут $((route_count+1)) (сеть/маска шлюз): " static_route
                        if [ -z "$static_route" ]; then
                            break
                        fi
                        routes="$routes\nRoute=$static_route"
                        route_count=$((route_count+1))
                    done
                fi

                # Создаем конфиг
                mkdir -p $NETWORKD_DIR
                cat > "$network_file" << EOF
[Match]
Name=$network_iface

[Network]
$( [ -n "$sysd_gateway" ] && echo "Gateway=$sysd_gateway" )
$( [ -n "$routes" ] && echo -e "$routes" )
EOF

                echo -e "\n${GREEN}Конфиг создан:${NC}"
                cat "$network_file"

                # Применяем
                echo -e "\nПрименяем изменения..."
                systemctl restart systemd-networkd

                echo -e "\n${GREEN}Новая таблица маршрутизации:${NC}"
                ip route show
            fi
            ;;

        7)
            # Проверить маршрут до хоста
            echo -e "\n${YELLOW}Проверка маршрута до хоста:${NC}"

            read -p "Введите IP адрес или домен для проверки: " check_host

            if [ -z "$check_host" ]; then
                echo -e "${RED}Хост не указан!${NC}"
                return 1
            fi

            echo -e "\n${GREEN}Traceroute до $check_host:${NC}"
            if command -v traceroute >/dev/null; then
                traceroute -n -m 5 $check_host 2>/dev/null || echo "Traceroute не доступен"
            else
                echo "Установите traceroute: apt install traceroute"
            fi

            echo -e "\n${GREEN}Проверка маршрута через mtr:${NC}"
            if command -v mtr >/dev/null; then
                mtr -n -c 3 $check_host 2>/dev/null || echo "MTR не доступен"
            else
                echo "Установите mtr: apt install mtr"
            fi
            ;;

        *)
            echo "Неверный выбор"
            ;;
    esac

    echo -e "\n${YELLOW}Текущая таблица маршрутизации:${NC}"
    ip -c route show

    read -p "Нажмите Enter для продолжения..."
}

# Функция 23: Управление переименованием сетевых интерфейсов
manage_interface_renaming() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ ПЕРЕИМЕНОВАНИЕМ СЕТЕВЫХ ИНТЕРФЕЙСОВ ===${NC}\n"

    echo -e "${YELLOW}Текущие сетевые интерфейсы:${NC}"
    echo "══════════════════════════════════════════"
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo
    echo ""

    echo -e "${YELLOW}Информация о сетевых картах:${NC}"
    echo "══════════════════════════════════════════"
    lshw -class network -short 2>/dev/null || echo "lshw не установлен. Установите: apt install lshw"
    echo ""

    echo -e "${YELLOW}Опции управления:${NC}"
    echo "1. Показать текущие параметры GRUB"
    echo "2. Отключить переименование интерфейсов (predictable)"
    echo "3. Включить переименование интерфейсов (predictable)"
    echo "4. Использовать старые имена (ethX)"
    echo "5. Использовать имена на основе MAC адресов"
    echo "6. Применить правила udev для статических имен"
    echo "7. Восстановить настройки по умолчанию"
    read -p "Выберите опцию [1-7]: " rename_option

    case $rename_option in
        1)
            echo -e "\n${YELLOW}Текущие параметры GRUB:${NC}"
            echo "══════════════════════════════════════════"
            if [ -f /etc/default/grub ]; then
                grep -i "net.ifnames\|biosdevname\|quiet" /etc/default/grub || echo "Параметры не найдены"
            else
                echo "Файл /etc/default/grub не найден"
            fi

            echo -e "\n${YELLOW}Текущие параметры ядра:${NC}"
            echo "══════════════════════════════════════════"
            cat /proc/cmdline | tr ' ' '\n' | grep -E "net.ifnames|biosdevname" || echo "Параметры не установлены"
            ;;

        2)
            echo -e "\n${YELLOW}Отключение предсказуемых имен интерфейсов...${NC}"

            # Резервная копия файла grub
            cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)

            # Проверяем текущие параметры GRUB_CMDLINE_LINUX
            if grep -q "GRUB_CMDLINE_LINUX=" /etc/default/grub; then
                # Получаем текущую строку
                current_cmdline=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub | cut -d'"' -f2)

                # Добавляем параметры если их нет
                if [[ ! $current_cmdline =~ net.ifnames=0 ]]; then
                    new_cmdline="$current_cmdline net.ifnames=0"
                else
                    new_cmdline="$current_cmdline"
                fi

                if [[ ! $current_cmdline =~ biosdevname=0 ]]; then
                    new_cmdline="$new_cmdline biosdevname=0"
                fi

                # Удаляем лишние пробелы
                new_cmdline=$(echo "$new_cmdline" | sed 's/  */ /g')

                # Обновляем файл grub
                sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$new_cmdline\"/" /etc/default/grub

                echo -e "${GREEN}Параметры обновлены:${NC}"
                grep "GRUB_CMDLINE_LINUX=" /etc/default/grub

                # Обновляем GRUB
                echo -e "\n${YELLOW}Обновляем конфигурацию GRUB...${NC}"
                if [ -d /sys/firmware/efi ]; then
                    update-grub
                else
                    grub-mkconfig -o /boot/grub/grub.cfg
                fi

                echo -e "\n${GREEN}Готово!${NC}"
                echo "Для применения изменений необходима перезагрузка."
                echo "После перезагрузки интерфейсы будут использовать старые имена (eth0, eth1 и т.д.)"
            else
                echo -e "${RED}Ошибка: Не найдена строка GRUB_CMDLINE_LINUX${NC}"
            fi
            ;;

        3)
            echo -e "\n${YELLOW}Включение предсказуемых имен интерфейсов...${NC}"

            # Резервная копия
            cp /etc/default/grub /etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)

            if grep -q "GRUB_CMDLINE_LINUX=" /etc/default/grub; then
                current_cmdline=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub | cut -d'"' -f2)

                # Удаляем параметры отключения
                new_cmdline=$(echo "$current_cmdline" | sed 's/net.ifnames=0//g' | sed 's/biosdevname=0//g')
                new_cmdline=$(echo "$new_cmdline" | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

                sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$new_cmdline\"/" /etc/default/grub

                echo -e "${GREEN}Параметры обновлены:${NC}"
                grep "GRUB_CMDLINE_LINUX=" /etc/default/grub

                # Обновляем GRUB
                echo -e "\n${YELLOW}Обновляем конфигурацию GRUB...${NC}"
                if [ -d /sys/firmware/efi ]; then
                    update-grub
                else
                    grub-mkconfig -o /boot/grub/grub.cfg
                fi

                echo -e "\n${GREEN}Готово!${NC}"
                echo "После перезагрузки будут использоваться предсказуемые имена (enpXsY)."
            fi
            ;;

        4)
            echo -e "\n${YELLOW}Настройка старых имен ethX...${NC}"

            # Отключаем predictable и biosdevname
            manage_interface_renaming_option "net.ifnames=0 biosdevname=0"

            echo -e "\n${GREEN}Настройка завершена!${NC}"
            echo "После перезагрузки интерфейсы будут называться eth0, eth1 и т.д."
            ;;

        5)
            echo -e "\n${YELLOW}Настройка имен на основе MAC адресов...${NC}"

            # Создаем правила udev
            udev_dir="/etc/udev/rules.d"
            udev_file="$udev_dir/10-network.rules"

            echo "Создаем правила udev..."
            echo "# Статические имена на основе MAC адресов" > $udev_file

            # Получаем информацию о сетевых интерфейсах
            ip -o link show | grep -v lo | while read line; do
                iface=$(echo $line | awk -F': ' '{print $2}')
                mac=$(echo $line | awk -F' ' '{print $17}')

                if [ -n "$mac" ] && [ "$mac" != "00:00:00:00:00:00" ]; then
                    echo "SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"$mac\", NAME=\"eth$(echo $iface | sed 's/[^0-9]*//g')\"" >> $udev_file
                    echo "Добавлено правило для $iface ($mac)"
                fi
            done

            echo -e "\n${GREEN}Правила udev созданы:${NC}"
            cat $udev_file

            # Отключаем systemd-networkd переименование
            manage_interface_renaming_option "net.ifnames=0"

            echo -e "\n${YELLOW}Для применения правил udev:${NC}"
            echo "1. Перезагрузите систему"
            echo "ИЛИ"
            echo "2. Выполните команды:"
            echo "   udevadm control --reload-rules"
            echo "   udevadm trigger --type=subsystems --action=add"
            ;;

        6)
            echo -e "\n${YELLOW}Настройка статических имен через udev...${NC}"

            udev_dir="/etc/udev/rules.d"
            udev_file="$udev_dir/70-persistent-net.rules"

            echo "Создаем файл правил udev..."
            echo "# Persistent network device naming" > $udev_file

            # Счетчик для ethX
            eth_counter=0

            # Получаем информацию о физических сетевых картах
            for dev in /sys/class/net/*; do
                iface=$(basename $dev)

                # Пропускаем виртуальные интерфейсы
                if [[ $iface == lo* ]] || [[ $iface == docker* ]] || [[ $iface == br-* ]] || [[ $iface == veth* ]]; then
                    continue
                fi

                # Получаем MAC адрес
                if [ -f "$dev/address" ]; then
                    mac=$(cat "$dev/address" | tr '[:lower:]' '[:upper:]')

                    if [ "$mac" != "00:00:00:00:00:00" ]; then
                        # Получаем информацию о PCI
                        if [ -L "$dev/device" ]; then
                            pci_path=$(readlink -f "$dev/device")
                            pci_id=$(basename $pci_path)

                            echo "# PCI device $pci_id" >> $udev_file
                            echo "SUBSYSTEM==\"net\", ACTION==\"add\", DRIVERS==\"?*\", ATTR{address}==\"$mac\", ATTR{dev_id}==\"0x0\", ATTR{type}==\"1\", KERNEL==\"eth*\", NAME=\"eth${eth_counter}\"" >> $udev_file

                            echo "Добавлено: $iface (MAC: $mac) -> eth${eth_counter}"
                            eth_counter=$((eth_counter + 1))
                        fi
                    fi
                fi
            done

            # Применяем правила
            echo -e "\n${YELLOW}Применяем правила...${NC}"
            udevadm control --reload-rules
            udevadm trigger --type=subsystems --action=add

            echo -e "\n${GREEN}Правила созданы:${NC}"
            cat $udev_file

            echo -e "\n${YELLOW}Необходима перезагрузка для применения изменений.${NC}"
            ;;

        7)
            echo -e "\n${YELLOW}Восстановление настроек по умолчанию...${NC}"

            # Восстанавливаем оригинальный GRUB
            if [ -f /etc/default/grub.backup.* ]; then
                latest_backup=$(ls -t /etc/default/grub.backup.* | head -1)
                if [ -f "$latest_backup" ]; then
                    cp "$latest_backup" /etc/default/grub
                    echo "Восстановлен GRUB из $latest_backup"
                fi
            else
                # Удаляем параметры из GRUB
                sed -i 's/net.ifnames=0//g' /etc/default/grub
                sed -i 's/biosdevname=0//g' /etc/default/grub
                sed -i 's/  */ /g' /etc/default/grub
                sed -i 's/^ //' /etc/default/grub
                sed -i 's/ $//' /etc/default/grub
                echo "Параметры удалены из GRUB"
            fi

            # Удаляем правила udev
            rm -f /etc/udev/rules.d/10-network.rules
            rm -f /etc/udev/rules.d/70-persistent-net.rules

            # Обновляем GRUB
            update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg

            # Перезагружаем udev
            udevadm control --reload-rules
            udevadm trigger

            echo -e "\n${GREEN}Настройки восстановлены!${NC}"
            echo "Перезагрузите систему для применения изменений."
            ;;

        *)
            echo "Неверный выбор"
            ;;
    esac

    echo -e "\n${YELLOW}Текущие параметры загрузки:${NC}"
    cat /proc/cmdline | grep -o "net.ifnames[^ ]*\|biosdevname[^ ]*" || echo "Параметры не установлены"

    read -p "Нажмите Enter для продолжения..."
}

# Вспомогательная функция для изменения параметров GRUB
manage_interface_renaming_option() {
    local params=$1

    if [ ! -f /etc/default/grub ]; then
        echo -e "${RED}Файл /etc/default/grub не найден!${NC}"
        return 1
    fi

    # Создаем резервную копию
    backup_file="/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"
    cp /etc/default/grub "$backup_file"

    # Обновляем параметры GRUB_CMDLINE_LINUX
    if grep -q "GRUB_CMDLINE_LINUX=" /etc/default/grub; then
        current_line=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub)
        current_params=$(echo "$current_line" | cut -d'"' -f2)

        # Удаляем старые параметры переименования
        cleaned_params=$(echo "$current_params" | sed 's/net.ifnames=[0-9]//g' | sed 's/biosdevname=[0-9]//g')
        cleaned_params=$(echo "$cleaned_params" | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

        # Добавляем новые параметры
        new_params="$cleaned_params $params"
        new_params=$(echo "$new_params" | sed 's/  */ /g' | sed 's/^ //' | sed 's/ $//')

        # Обновляем файл
        sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$new_params\"|" /etc/default/grub

        echo -e "${GREEN}Параметры обновлены:${NC}"
        grep "GRUB_CMDLINE_LINUX=" /etc/default/grub

        # Обновляем конфигурацию GRUB
        echo -e "\n${YELLOW}Обновляем конфигурацию GRUB...${NC}"
        if command -v update-grub >/dev/null; then
            update-grub
        elif command -v grub-mkconfig >/dev/null; then
            grub-mkconfig -o /boot/grub/grub.cfg
        else
            echo -e "${YELLOW}Команда обновления GRUB не найдена${NC}"
        fi

        echo -e "\n${GREEN}Конфигурация обновлена!${NC}"
        echo -e "${YELLOW}Для применения изменений необходима перезагрузка.${NC}"

    else
        echo -e "${RED}Ошибка: Не найдена строка GRUB_CMDLINE_LINUX${NC}"
    fi
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
            22) manage_routing ;;
            23) manage_interface_renaming ;;
            24)
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
