#!/bin/bash
# DHCP Server Manager for Ubuntu Server 24.04
# Interactive diagnostic and configuration tool

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Основные переменные
DEFAULT_INTERFACE="enp2s0"
DEFAULT_SUBNET="192.168.10.0/24"
DEFAULT_SERVER_IP="192.168.10.1"
DEFAULT_DHCP_RANGE_START="192.168.10.100"
DEFAULT_DHCP_RANGE_END="192.168.10.200"
BACKUP_DIR="/root/network_backup_$(date +%Y%m%d_%H%M%S)"

# Функция для отображения меню
show_menu() {
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        DHCP Server Manager - Ubuntu Server 24.04         ║${NC}"
    echo -e "${BLUE}╠══════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} 1.  Полная диагностика сети и DHCP сервера            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 2.  Настроить DHCP сервер (isc-dhcp-server)          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 3.  Настроить DHCP сервер (dnsmasq - проще)          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 4.  Проверить и исправить IP адрес на интерфейсе     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 5.  Показать логи DHCP сервера                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 6.  Проверить клиентов DHCP (аренды)                 ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 7.  Мониторинг DHCP трафика в реальном времени       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 8.  Сбросить все сетевые настройки по умолчанию      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 9.  Резервное копирование сетевых конфигураций       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 10. Восстановить из резервной копии                  ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 11. Установить/переустановить DHCP сервер            ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 12. Перезапустить сетевые службы                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 13. Настроить статический IP на интерфейсе           ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 14. Показать текущую конфигурацию сети               ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 15. Тестирование соединения                          ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 16. Выход                                           ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    echo -n "Выберите опцию [1-16]: "
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
    
    # Сбор информации об интерфейсах
    echo -e "${YELLOW}1. СЕТЕВЫЕ ИНТЕРФЕЙСЫ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c addr show
    echo ""
    
    # Состояние интерфейсов
    echo -e "${YELLOW}2. СОСТОЯНИЕ ИНТЕРФЕЙСОВ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c link show
    echo ""
    
    # Маршрутизация
    echo -e "${YELLOW}3. ТАБЛИЦА МАРШРУТИЗАЦИИ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c route show
    echo ""
    
    # ARP таблица
    echo -e "${YELLOW}4. ARP ТАБЛИЦА:${NC}"
    echo "══════════════════════════════════════════"
    ip -c neigh show
    echo ""
    
    # Проверка служб DHCP
    echo -e "${YELLOW}5. СЛУЖБЫ DHCP:${NC}"
    echo "══════════════════════════════════════════"
    
    # Проверка isc-dhcp-server
    if systemctl is-active isc-dhcp-server >/dev/null 2>&1; then
        echo -e "isc-dhcp-server: ${GREEN}АКТИВЕН${NC}"
        systemctl status isc-dhcp-server --no-pager -l | head -10
    else
        echo -e "isc-dhcp-server: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
    
    # Проверка dnsmasq
    if systemctl is-active dnsmasq >/dev/null 2>&1; then
        echo -e "dnsmasq: ${GREEN}АКТИВЕН${NC}"
        systemctl status dnsmasq --no-pager -l | head -10
    else
        echo -e "dnsmasq: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
    
    # Проверка networkd
    echo -e "${YELLOW}6. SYSTEMD-NETWORKD:${NC}"
    echo "══════════════════════════════════════════"
    systemctl status systemd-networkd --no-pager -l | head -10
    echo ""
    
    # Проверка портов
    echo -e "${YELLOW}7. ОТКРЫТЫЕ ПОРТЫ DHCP (67,68):${NC}"
    echo "══════════════════════════════════════════"
    ss -tulpn | grep -E ':67|:68' | grep -v "127.0.0.1"
    echo ""
    
    # Конфигурационные файлы
    echo -e "${YELLOW}8. КОНФИГУРАЦИОННЫЕ ФАЙЛЫ:${NC}"
    echo "══════════════════════════════════════════"
    
    if [[ -f "/etc/netplan/"* ]]; then
        echo "Netplan конфиги:"
        ls -la /etc/netplan/
        for file in /etc/netplan/*.yaml; do
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
    
    # Проверка логов
    echo -e "${YELLOW}9. ПОСЛЕДНИЕ ЛОГИ DHCP:${NC}"
    echo "══════════════════════════════════════════"
    journalctl -u isc-dhcp-server -n 10 --no-pager 2>/dev/null || \
    journalctl -u dnsmasq -n 10 --no-pager 2>/dev/null || \
    echo "Логи DHCP не найдены"
    echo ""
    
    # Проверка leases
    echo -e "${YELLOW}10. АРЕНДЫ DHCP:${NC}"
    echo "══════════════════════════════════════════"
    if [[ -f "/var/lib/dhcp/dhcpd.leases" ]]; then
        echo "Активные аренды:"
        grep -E "lease|starts|ends|hardware" /var/lib/dhcp/dhcpd.leases | tail -20
    elif [[ -f "/var/lib/misc/dnsmasq.leases" ]]; then
        echo "Аренды dnsmasq:"
        cat /var/lib/misc/dnsmasq.leases
    else
        echo "Файлы аренд не найдены"
    fi
    echo ""
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 2: Настройка isc-dhcp-server
setup_isc_dhcp() {
    echo -e "\n${GREEN}=== НАСТРОЙКА ISC-DHCP-SERVER ===${NC}\n"
    
    # Запрос параметров
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    read -p "Введите IP адрес сервера [$DEFAULT_SERVER_IP]: " server_ip
    server_ip=${server_ip:-$DEFAULT_SERVER_IP}
    
    read -p "Введите начальный IP пула DHCP [$DEFAULT_DHCP_RANGE_START]: " range_start
    range_start=${range_start:-$DEFAULT_DHCP_RANGE_START}
    
    read -p "Введите конечный IP пула DHCP [$DEFAULT_DHCP_RANGE_END]: " range_end
    range_end=${range_end:-$DEFAULT_DHCP_RANGE_END}
    
    # Извлекаем подсеть из IP сервера
    subnet=$(echo $server_ip | cut -d'.' -f1-3)
    
    echo -e "\n${YELLOW}Настройка netplan...${NC}"
    # Создаем конфигурацию netplan
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
    cp /tmp/netplan-config.yaml /etc/netplan/00-dhcp-server.yaml
    netplan apply
    
    echo -e "\n${YELLOW}Проверяем IP на интерфейсе...${NC}"
    ip addr show $interface
    
    # Устанавливаем isc-dhcp-server если не установлен
    if ! dpkg -l | grep -q isc-dhcp-server; then
        echo "Устанавливаем isc-dhcp-server..."
        apt update
        apt install -y isc-dhcp-server
    fi
    
    echo -e "\n${YELLOW}Настраиваем dhcpd.conf...${NC}"
    # Создаем конфигурацию DHCP
    cat > /etc/dhcp/dhcpd.conf << EOF
# Конфигурация DHCP сервера
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
# Defaults for isc-dhcp-server
INTERFACESv4="$interface"
INTERFACESv6=""
DHCPD_CONF=/etc/dhcp/dhcpd.conf
DHCPD_PID=/var/run/dhcpd.pid
EOF
    
    # Создаем файл аренд если не существует
    touch /var/lib/dhcp/dhcpd.leases
    chown dhcpd:dhcpd /var/lib/dhcp/dhcpd.leases
    
    echo -e "\n${YELLOW}Проверяем синтаксис конфигурации...${NC}"
    if dhcpd -t; then
        echo -e "${GREEN}Синтаксис конфигурации правильный!${NC}"
        
        # Перезапускаем службу
        systemctl stop isc-dhcp-server 2>/dev/null
        systemctl start isc-dhcp-server
        systemctl enable isc-dhcp-server
        
        echo -e "\n${GREEN}Статус службы:${NC}"
        systemctl status isc-dhcp-server --no-pager -l | head -10
    else
        echo -e "${RED}Ошибка в синтаксисе конфигурации!${NC}"
    fi
    
    echo -e "\n${YELLOW}Проверяем открытые порты...${NC}"
    ss -tulpn | grep :67
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 3: Настройка dnsmasq (проще)
setup_dnsmasq() {
    echo -e "\n${GREEN}=== НАСТРОЙКА DNSMASQ (ПРОСТОЙ DHCP СЕРВЕР) ===${NC}\n"
    
    # Запрос параметров
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    read -p "Введите IP адрес сервера [$DEFAULT_SERVER_IP]: " server_ip
    server_ip=${server_ip:-$DEFAULT_SERVER_IP}
    
    read -p "Введите начальный IP пула DHCP [$DEFAULT_DHCP_RANGE_START]: " range_start
    range_start=${range_start:-$DEFAULT_DHCP_RANGE_START}
    
    read -p "Введите конечный IP пула DHCP [$DEFAULT_DHCP_RANGE_END]: " range_end
    range_end=${range_end:-$DEFAULT_DHCP_RANGE_END}
    
    echo -e "\n${YELLOW}Настройка netplan...${NC}"
    # Создаем конфигурацию netplan
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
    cp /tmp/netplan-config.yaml /etc/netplan/00-dhcp-server.yaml
    netplan apply
    
    # Останавливаем isc-dhcp-server если запущен
    systemctl stop isc-dhcp-server 2>/dev/null
    systemctl disable isc-dhcp-server 2>/dev/null
    
    # Устанавливаем dnsmasq если не установлен
    if ! dpkg -l | grep -q dnsmasq; then
        echo "Устанавливаем dnsmasq..."
        apt update
        apt install -y dnsmasq
    fi
    
    echo -e "\n${YELLOW}Настраиваем dnsmasq...${NC}"
    # Создаем резервную копию оригинального конфига
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
    
    # Создаем минимальную конфигурацию
    cat > /etc/dnsmasq.conf << EOF
# Минимальная конфигурация DHCP сервера
interface=$interface
dhcp-range=$range_start,$range_end,255.255.255.0,12h
dhcp-option=option:router,$server_ip
dhcp-option=option:dns-server,8.8.8.8,8.8.4.4
bind-interfaces
no-resolv
no-poll
EOF
    
    echo -e "\n${YELLOW}Перезапускаем dnsmasq...${NC}"
    systemctl stop dnsmasq
    systemctl start dnsmasq
    systemctl enable dnsmasq
    
    echo -e "\n${GREEN}Статус службы:${NC}"
    systemctl status dnsmasq --no-pager -l | head -10
    
    echo -e "\n${YELLOW}Проверяем открытые порты...${NC}"
    ss -tulpn | grep :53
    ss -tulpn | grep :67
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 4: Проверить и исправить IP адрес
fix_ip_address() {
    echo -e "\n${GREEN}=== ПРОВЕРКА И ИСПРАВЛЕНИЕ IP АДРЕСА ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo -e "\n${YELLOW}Текущее состояние интерфейса $interface:${NC}"
    ip addr show $interface
    
    echo -e "\n${YELLOW}Опции:${NC}"
    echo "1. Назначить статический IP 192.168.10.1/24"
    echo "2. Включить DHCP на интерфейсе"
    echo "3. Сбросить настройки интерфейса"
    echo "4. Проверить физическое соединение"
    read -p "Выберите опцию [1-4]: " ip_option
    
    case $ip_option in
        1)
            read -p "Введите IP адрес [192.168.10.1]: " static_ip
            static_ip=${static_ip:-"192.168.10.1"}
            
            echo "Назначаем статический IP $static_ip/24 на $interface..."
            ip addr flush dev $interface
            ip addr add $static_ip/24 dev $interface
            ip link set $interface up
            
            echo -e "\n${GREEN}Результат:${NC}"
            ip addr show $interface
            ;;
        2)
            echo "Включаем DHCP на $interface..."
            
            # Создаем временный конфиг netplan
            cat > /tmp/dhcp-client.yaml << EOF
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: yes
      optional: true
EOF
            
            cp /tmp/dhcp-client.yaml /etc/netplan/01-dhcp-client.yaml
            netplan apply
            
            echo "Запрашиваем IP через DHCP..."
            dhclient -r $interface
            dhclient -v $interface
            ;;
        3)
            echo "Сбрасываем настройки интерфейса $interface..."
            ip addr flush dev $interface
            ip link set $interface down
            sleep 2
            ip link set $interface up
            
            echo -e "\n${GREEN}Состояние после сброса:${NC}"
            ip addr show $interface
            ;;
        4)
            echo "Проверяем физическое соединение..."
            ethtool $interface | grep -E "Link|Speed"
            
            echo -e "\nПроверяем статус линка:"
            ip link show $interface | grep -E "UP|DOWN"
            
            echo -e "\nСтатистика:"
            ip -s link show $interface
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 5: Показать логи DHCP сервера
show_dhcp_logs() {
    echo -e "\n${GREEN}=== ЛОГИ DHCP СЕРВЕРА ===${NC}\n"
    
    echo -e "${YELLOW}Выберите тип логов:${NC}"
    echo "1. Логи isc-dhcp-server (последние 50 строк)"
    echo "2. Логи dnsmasq (последние 50 строк)"
    echo "3. Логи systemd-networkd"
    echo "4. Просмотр в реальном времени (tail -f)"
    echo "5. Поиск ошибок в логах"
    read -p "Выберите опцию [1-5]: " log_option
    
    case $log_option in
        1)
            echo -e "\n${YELLOW}Логи isc-dhcp-server:${NC}"
            journalctl -u isc-dhcp-server -n 50 --no-pager
            ;;
        2)
            echo -e "\n${YELLOW}Логи dnsmasq:${NC}"
            journalctl -u dnsmasq -n 50 --no-pager
            ;;
        3)
            echo -e "\n${YELLOW}Логи systemd-networkd:${NC}"
            journalctl -u systemd-networkd -n 30 --no-pager
            ;;
        4)
            echo -e "\n${YELLOW}Просмотр логов в реальном времени...${NC}"
            echo "Нажмите Ctrl+C для остановки"
            
            echo -e "\nВыберите службу:"
            echo "1. isc-dhcp-server"
            echo "2. dnsmasq"
            echo "3. systemd-networkd"
            echo "4. syslog (все логи)"
            read -p "Выбор [1-4]: " realtime_choice
            
            case $realtime_choice in
                1) journalctl -u isc-dhcp-server -f ;;
                2) journalctl -u dnsmasq -f ;;
                3) journalctl -u systemd-networkd -f ;;
                4) tail -f /var/log/syslog ;;
                *) echo "Неверный выбор" ;;
            esac
            ;;
        5)
            echo -e "\n${YELLOW}Поиск ошибок в логах:${NC}"
            echo -e "1. Ошибки isc-dhcp-server\n2. Ошибки dnsmasq\n3. Критические ошибки сети"
            read -p "Выбор [1-3]: " error_choice
            
            case $error_choice in
                1) journalctl -u isc-dhcp-server --no-pager | grep -i "error\|fail\|failed" | tail -20 ;;
                2) journalctl -u dnsmasq --no-pager | grep -i "error\|fail\|failed" | tail -20 ;;
                3) journalctl --no-pager | grep -i "network\|dhcp\|error" | tail -30 ;;
                *) echo "Неверный выбор" ;;
            esac
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 6: Проверить клиентов DHCP
check_dhcp_clients() {
    echo -e "\n${GREEN}=== ПРОВЕРКА КЛИЕНТОВ DHCP ===${NC}\n"
    
    echo -e "${YELLOW}1. Активные аренды DHCP:${NC}"
    echo "══════════════════════════════════════════"
    
    # Проверяем разные возможные места хранения leases
    if [[ -f "/var/lib/dhcp/dhcpd.leases" ]]; then
        echo "Файл: /var/lib/dhcp/dhcpd.leases"
        echo "Последние аренды:"
        grep -A4 "lease " /var/lib/dhcp/dhcpd.leases | tail -40
    elif [[ -f "/var/lib/misc/dnsmasq.leases" ]]; then
        echo "Файл: /var/lib/misc/dnsmasq.leases"
        cat /var/lib/misc/dnsmasq.leases
    else
        echo "Файлы аренд не найдены"
        
        # Создаем пустой файл если не существует
        echo "Создаем тестовый файл аренд..."
        touch /var/lib/dhcp/dhcpd.leases
        chown dhcpd:dhcpd /var/lib/dhcp/dhcpd.leases
    fi
    
    echo -e "\n${YELLOW}2. ARP таблица (соседние устройства):${NC}"
    echo "══════════════════════════════════════════"
    ip neigh show
    
    echo -e "\n${YELLOW}3. Мониторинг DHCP трафика (5 секунд):${NC}"
    echo "══════════════════════════════════════════"
    echo "Нажмите Ctrl+C для досрочной остановки"
    timeout 5 tcpdump -i any -n port 67 or port 68 2>/dev/null || \
        echo "tcpdump не установлен. Установите: apt install tcpdump"
    
    echo -e "\n${YELLOW}4. Статистика DHCP сервера:${NC}"
    echo "══════════════════════════════════════════"
    if systemctl is-active isc-dhcp-server >/dev/null 2>&1; then
        echo "isc-dhcp-server статистика:"
        systemctl status isc-dhcp-server --no-pager -l | grep -A5 "Active:"
    fi
    
    if systemctl is-active dnsmasq >/dev/null 2>&1; then
        echo -e "\ndnsmasq статистика:"
        systemctl status dnsmasq --no-pager -l | grep -A5 "Active:"
    fi
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 7: Мониторинг DHCP трафика
monitor_dhcp_traffic() {
    echo -e "\n${GREEN}=== МОНИТОРИНГ DHCP ТРАФИКА ===${NC}\n"
    
    # Проверяем установлен ли tcpdump
    if ! command -v tcpdump &> /dev/null; then
        echo "Установка tcpdump..."
        apt update
        apt install -y tcpdump
    fi
    
    read -p "Введите имя интерфейса для мониторинга [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo -e "\n${YELLOW}Выберите тип мониторинга:${NC}"
    echo "1. Только DHCP пакеты (Discover, Offer, Request, Ack)"
    echo "2. Подробный мониторинг с содержимым пакетов"
    echo "3. Мониторинг всех широковещательных пакетов"
    echo "4. Запись трафика в файл"
    read -p "Выберите опцию [1-4]: " monitor_option
    
    echo -e "\n${GREEN}Начинаем мониторинг на интерфейсе $interface...${NC}"
    echo "Нажмите Ctrl+C для остановки"
    echo ""
    
    case $monitor_option in
        1)
            # Только DHCP пакеты
            tcpdump -i $interface -n -vvv "port 67 or port 68"
            ;;
        2)
            # Подробный мониторинг
            tcpdump -i $interface -n -X -s0 "port 67 or port 68"
            ;;
        3)
            # Все широковещательные пакеты
            tcpdump -i $interface -n "broadcast"
            ;;
        4)
            # Запись в файл
            read -p "Введите имя файла для записи [dhcp_capture.pcap]: " pcap_file
            pcap_file=${pcap_file:-"dhcp_capture.pcap"}
            
            echo "Записываем трафик в файл $pcap_file..."
            echo "Нажмите Ctrl+C для остановки записи"
            tcpdump -i $interface -n -w "/tmp/$pcap_file" "port 67 or port 68"
            
            echo -e "\n${GREEN}Запись завершена. Файл: /tmp/$pcap_file${NC}"
            echo "Для анализа используйте: tcpdump -r /tmp/$pcap_file -n"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 8: Сброс всех сетевых настроек
reset_network_default() {
    echo -e "\n${RED}=== СБРОС ВСЕХ СЕТЕВЫХ НАСТРОЕК ===${NC}\n"
    
    echo -e "${RED}ВНИМАНИЕ! Эта операция:${NC}"
    echo "1. Удалит все текущие сетевые настройки"
    echo "2. Остановит все сетевые службы"
    echo "3. Вернет интерфейсы в режим DHCP"
    echo "4. Может прервать текущее SSH соединение!"
    
    read -p "Вы уверены? (y/N): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo "Отмена операции."
        return
    fi
    
    echo -e "\n${YELLOW}Выполняем сброс сетевых настроек...${NC}"
    
    # Создаем резервную копию
    mkdir -p $BACKUP_DIR
    cp -r /etc/netplan/ $BACKUP_DIR/netplan/ 2>/dev/null
    cp /etc/dhcp/dhcpd.conf $BACKUP_DIR/ 2>/dev/null
    cp /etc/dnsmasq.conf $BACKUP_DIR/ 2>/dev/null
    cp /etc/default/isc-dhcp-server $BACKUP_DIR/ 2>/dev/null
    
    echo -e "\n1. Останавливаем сетевые службы..."
    systemctl stop isc-dhcp-server 2>/dev/null
    systemctl stop dnsmasq 2>/dev/null
    systemctl stop systemd-networkd 2>/dev/null
    systemctl stop NetworkManager 2>/dev/null
    
    echo -e "\n2. Сбрасываем все интерфейсы..."
    # Получаем список всех физических интерфейсов
    interfaces=$(ip link show | grep -E "^[0-9]+:" | grep -v lo | awk -F': ' '{print $2}' | grep -v '@')
    
    for iface in $interfaces; do
        echo "Сбрасываем интерфейс $iface..."
        ip addr flush dev $iface
        ip link set $iface down
        ip link set $iface up
        dhclient -r $iface 2>/dev/null
    done
    
    echo -e "\n3. Очищаем конфигурацию netplan..."
    rm -f /etc/netplan/*.yaml
    
    # Создаем простую конфигурацию DHCP для всех интерфейсов
    cat > /etc/netplan/00-default-dhcp.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
EOF
    
    for iface in $interfaces; do
        cat >> /etc/netplan/00-default-dhcp.yaml << EOF
    $iface:
      dhcp4: yes
      dhcp6: no
      optional: true
EOF
    done
    
    echo -e "\n4. Применяем настройки..."
    netplan generate
    netplan apply
    
    echo -e "\n5. Запрашиваем DHCP адреса..."
    for iface in $interfaces; do
        dhclient -v $iface &
    done
    
    sleep 3
    
    echo -e "\n${GREEN}Сброс завершен!${NC}"
    echo -e "\n${YELLOW}Текущая конфигурация:${NC}"
    ip addr show
    
    echo -e "\n${YELLOW}Резервная копия сохранена в: $BACKUP_DIR${NC}"
    echo -e "\n${RED}ВНИМАНИЕ: Если вы подключены по SSH, соединение может прерваться!${NC}"
    echo "Подождите 30 секунд и попробуйте подключиться заново."
    
    echo -e "\nЧерез 10 секунд будет выполнена перезагрузка сети..."
    for i in {10..1}; do
        echo -ne "Перезагрузка через $i секунд...\r"
        sleep 1
    done
    
    systemctl restart systemd-networkd
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 9: Резервное копирование
backup_configs() {
    echo -e "\n${GREEN}=== РЕЗЕРВНОЕ КОПИРОВАНИЕ КОНФИГУРАЦИЙ ===${NC}\n"
    
    backup_dir="/root/network_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $backup_dir
    
    echo "Создаем резервную копию в $backup_dir..."
    
    # Копируем конфигурационные файлы
    files_to_backup=(
        "/etc/netplan/"
        "/etc/dhcp/"
        "/etc/dnsmasq.conf"
        "/etc/default/isc-dhcp-server"
        "/etc/hostname"
        "/etc/hosts"
        "/etc/resolv.conf"
        "/var/lib/dhcp/dhcpd.leases"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -e $file ]]; then
            echo "Копируем $file..."
            cp -r $file $backup_dir/ 2>/dev/null
        fi
    done
    
    # Сохраняем текущее состояние сети
    echo "Сохраняем состояние сети..."
    ip addr show > $backup_dir/ip_addr.txt
    ip route show > $backup_dir/ip_route.txt
    ip link show > $backup_dir/ip_link.txt
    ss -tulpn > $backup_dir/open_ports.txt
    
    # Создаем скрипт восстановления
    cat > $backup_dir/restore_network.sh << 'EOF'
#!/bin/bash
# Скрипт восстановления сетевых настроек

if [[ $EUID -ne 0 ]]; then
    echo "Этот скрипт должен запускаться с правами root!"
    exit 1
fi

echo "Восстановление сетевых настроек..."

# Восстанавливаем файлы
cp -r netplan/* /etc/netplan/ 2>/dev/null
cp dhcpd.conf /etc/dhcp/ 2>/dev/null
cp dnsmasq.conf /etc/ 2>/dev/null
cp isc-dhcp-server /etc/default/ 2>/dev/null
cp dhcpd.leases /var/lib/dhcp/ 2>/dev/null

# Применяем настройки
netplan apply

echo "Готово! Может потребоваться перезагрузка."
EOF
    
    chmod +x $backup_dir/restore_network.sh
    
    # Создаем архив
    cd $(dirname $backup_dir)
    tar -czf $(basename $backup_dir).tar.gz $(basename $backup_dir)
    
    echo -e "\n${GREEN}Резервная копия создана:${NC}"
    echo "Директория: $backup_dir"
    echo "Архив: $backup_dir.tar.gz"
    echo "Скрипт восстановления: $backup_dir/restore_network.sh"
    
    ls -la $backup_dir
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 10: Восстановление из резервной копии
restore_backup() {
    echo -e "\n${GREEN}=== ВОССТАНОВЛЕНИЕ ИЗ РЕЗЕРВНОЙ КОПИИ ===${NC}\n"
    
    echo "Доступные резервные копии:"
    find /root -name "network_backup_*" -type d 2>/dev/null | sort -r
    
    read -p "Введите полный путь к резервной копии: " backup_path
    
    if [[ ! -d $backup_path ]]; then
        echo -e "${RED}Директория не найдена!${NC}"
        read -p "Нажмите Enter для продолжения..."
        return
    fi
    
    echo -e "\n${YELLOW}Содержимое резервной копии:${NC}"
    ls -la $backup_path
    
    read -p "Вы уверены, что хотите восстановить настройки из этой копии? (y/N): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo "Отмена операции."
        return
    fi
    
    echo -e "\n${YELLOW}Восстанавливаем файлы...${NC}"
    
    # Создаем резервную копию текущих настроек
    current_backup="/tmp/current_network_backup_$(date +%s)"
    mkdir -p $current_backup
    
    # Копируем текущие настройки
    cp -r /etc/netplan $current_backup/ 2>/dev/null
    cp /etc/dhcp/dhcpd.conf $current_backup/ 2>/dev/null
    cp /etc/dnsmasq.conf $current_backup/ 2>/dev/null
    cp /etc/default/isc-dhcp-server $current_backup/ 2>/dev/null
    
    # Восстанавливаем из резервной копии
    if [[ -d "$backup_path/netplan" ]]; then
        rm -rf /etc/netplan/*
        cp -r $backup_path/netplan/* /etc/netplan/ 2>/dev/null
        echo "Восстановлен netplan"
    fi
    
    if [[ -f "$backup_path/dhcpd.conf" ]]; then
        cp $backup_path/dhcpd.conf /etc/dhcp/ 2>/dev/null
        echo "Восстановлен dhcpd.conf"
    fi
    
    if [[ -f "$backup_path/dnsmasq.conf" ]]; then
        cp $backup_path/dnsmasq.conf /etc/ 2>/dev/null
        echo "Восстановлен dnsmasq.conf"
    fi
    
    if [[ -f "$backup_path/isc-dhcp-server" ]]; then
        cp $backup_path/isc-dhcp-server /etc/default/ 2>/dev/null
        echo "Восстановлен isc-dhcp-server"
    fi
    
    if [[ -f "$backup_path/dhcpd.leases" ]]; then
        cp $backup_path/dhcpd.leases /var/lib/dhcp/ 2>/dev/null
        chown dhcpd:dhcpd /var/lib/dhcp/dhcpd.leases
        echo "Восстановлен dhcpd.leases"
    fi
    
    echo -e "\n${YELLOW}Применяем настройки...${NC}"
    netplan apply
    
    # Перезапускаем службы
    systemctl restart systemd-networkd 2>/dev/null
    
    if [[ -f "/etc/dhcp/dhcpd.conf" ]]; then
        systemctl restart isc-dhcp-server 2>/dev/null
    fi
    
    if [[ -f "/etc/dnsmasq.conf" ]]; then
        systemctl restart dnsmasq 2>/dev/null
    fi
    
    echo -e "\n${GREEN}Восстановление завершено!${NC}"
    echo "Текущая резервная копия сохранена в: $current_backup"
    
    echo -e "\n${YELLOW}Текущая конфигурация сети:${NC}"
    ip addr show
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 11: Установка/переустановка DHCP сервера
install_dhcp_server() {
    echo -e "\n${GREEN}=== УСТАНОВКА/ПЕРЕУСТАНОВКА DHCP СЕРВЕРА ===${NC}\n"
    
    echo -e "${YELLOW}Выберите DHCP сервер:${NC}"
    echo "1. isc-dhcp-server (стандартный, больше настроек)"
    echo "2. dnsmasq (проще, легче, включает DNS)"
    echo "3. Удалить все DHCP серверы"
    echo "4. Установить оба"
    read -p "Выберите опцию [1-4]: " install_option
    
    case $install_option in
        1)
            echo -e "\n${YELLOW}Установка isc-dhcp-server...${NC}"
            apt update
            apt install -y isc-dhcp-server
            
            echo -e "\n${GREEN}Установка завершена!${NC}"
            echo "Используйте опцию 2 в главном меню для настройки."
            ;;
        2)
            echo -e "\n${YELLOW}Установка dnsmasq...${NC}"
            apt update
            apt install -y dnsmasq
            
            echo -e "\n${GREEN}Установка завершена!${NC}"
            echo "Используйте опцию 3 в главном меню для настройки."
            ;;
        3)
            echo -e "\n${YELLOW}Удаление всех DHCP серверов...${NC}"
            apt remove -y isc-dhcp-server dnsmasq
            apt autoremove -y
            
            echo "Очищаем конфигурационные файлы..."
            rm -rf /etc/dhcp/
            rm -f /etc/dnsmasq.conf
            rm -f /etc/default/isc-dhcp-server
            
            echo -e "\n${GREEN}Все DHCP серверы удалены!${NC}"
            ;;
        4)
            echo -e "\n${YELLOW}Установка обоих DHCP серверов...${NC}"
            apt update
            apt install -y isc-dhcp-server dnsmasq
            
            echo -e "\n${GREEN}Установка завершена!${NC}"
            echo "Внимание: Оба сервера не могут работать одновременно на одних портах!"
            echo "Отключите один из них перед использованием."
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 12: Перезапуск сетевых служб
restart_network_services() {
    echo -e "\n${GREEN}=== ПЕРЕЗАПУСК СЕТЕВЫХ СЛУЖБ ===${NC}\n"
    
    echo -e "${YELLOW}Выберите службы для перезапуска:${NC}"
    echo "1. Все сетевые службы (полный перезапуск)"
    echo "2. Только systemd-networkd"
    echo "3. Только DHCP серверы"
    echo "4. Только DNS службы"
    echo "5. Сброс кэша DNS"
    read -p "Выберите опцию [1-5]: " restart_option
    
    case $restart_option in
        1)
            echo "Выполняем полный перезапуск сетевых служб..."
            systemctl restart systemd-networkd
            systemctl restart isc-dhcp-server 2>/dev/null
            systemctl restart dnsmasq 2>/dev/null
            systemctl restart systemd-resolved
            netplan apply
            echo -e "\n${GREEN}Все сетевые службы перезапущены!${NC}"
            ;;
        2)
            echo "Перезапускаем systemd-networkd..."
            systemctl restart systemd-networkd
            echo -e "\n${GREEN}systemd-networkd перезапущен!${NC}"
            ;;
        3)
            echo "Перезапускаем DHCP серверы..."
            systemctl restart isc-dhcp-server 2>/dev/null
            systemctl restart dnsmasq 2>/dev/null
            echo -e "\n${GREEN}DHCP серверы перезапущены!${NC}"
            ;;
        4)
            echo "Перезапускаем DNS службы..."
            systemctl restart dnsmasq 2>/dev/null
            systemctl restart systemd-resolved
            echo -e "\n${GREEN}DNS службы перезапущены!${NC}"
            ;;
        5)
            echo "Сбрасываем кэш DNS..."
            systemd-resolve --flush-caches
            if systemctl is-active dnsmasq >/dev/null 2>&1; then
                systemctl restart dnsmasq
            fi
            echo -e "\n${GREEN}Кэш DNS сброшен!${NC}"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    echo -e "\n${YELLOW}Статус служб после перезапуска:${NC}"
    echo "══════════════════════════════════════════"
    systemctl status systemd-networkd --no-pager -l | head -5
    systemctl status isc-dhcp-server --no-pager -l 2>/dev/null | head -5
    systemctl status dnsmasq --no-pager -l 2>/dev/null | head -5
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 13: Настроить статический IP
setup_static_ip() {
    echo -e "\n${GREEN}=== НАСТРОЙКА СТАТИЧЕСКОГО IP ===${NC}\n"
    
    read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo -e "\n${YELLOW}Текущие настройки интерфейса $interface:${NC}"
    ip addr show $interface
    
    read -p "Введите статический IP адрес [192.168.10.1]: " static_ip
    static_ip=${static_ip:-"192.168.10.1"}
    
    read -p "Введите маску подсети (например, 24 для /24) [24]: " netmask
    netmask=${netmask:-"24"}
    
    read -p "Введите шлюз (gateway) [192.168.10.1]: " gateway
    gateway=${gateway:-$static_ip}
    
    read -p "Введите DNS серверы [8.8.8.8,8.8.4.4]: " dns_servers
    dns_servers=${dns_servers:-"8.8.8.8,8.8.4.4"}
    
    # Преобразуем netmask в формат /24
    if [[ $netmask =~ ^[0-9]+$ ]]; then
        netmask="/$netmask"
    fi
    
    echo -e "\n${YELLOW}Новые настройки:${NC}"
    echo "Интерфейс: $interface"
    echo "IP адрес: $static_ip$netmask"
    echo "Шлюз: $gateway"
    echo "DNS: $dns_servers"
    
    read -p "Применить эти настройки? (y/N): " confirm
    if [[ $confirm != "y" && $confirm != "Y" ]]; then
        echo "Отмена."
        return
    fi
    
    # Создаем конфигурацию netplan
    config_file="/etc/netplan/99-static-$interface.yaml"
    
    cat > $config_file << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      addresses:
        - $static_ip$netmask
      routes:
        - to: default
          via: $gateway
      nameservers:
        addresses: [$(echo $dns_servers | sed 's/,/, /g')]
EOF
    
    echo -e "\n${YELLOW}Применяем настройки...${NC}"
    netplan apply
    
    echo -e "\n${GREEN}Настройки применены!${NC}"
    echo -e "\n${YELLOW}Проверяем новую конфигурацию:${NC}"
    ip addr show $interface
    ip route show | grep default
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 14: Показать текущую конфигурацию сети
show_network_config() {
    echo -e "\n${GREEN}=== ТЕКУЩАЯ КОНФИГУРАЦИЯ СЕТИ ===${NC}\n"
    
    echo -e "${YELLOW}1. ВСЕ СЕТЕВЫЕ ИНТЕРФЕЙСЫ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c -brief addr show
    
    echo -e "\n${YELLOW}2. ТАБЛИЦА МАРШРУТИЗАЦИИ:${NC}"
    echo "══════════════════════════════════════════"
    ip -c route show
    
    echo -e "\n${YELLOW}3. ФАЙЛЫ NETPLAN:${NC}"
    echo "══════════════════════════════════════════"
    if [[ -d /etc/netplan ]] && ls /etc/netplan/*.yaml 2>/dev/null; then
        for file in /etc/netplan/*.yaml; do
            echo -e "\nФайл: $file"
            cat "$file"
        done
    else
        echo "Netplan конфиги не найдены"
    fi
    
    echo -e "\n${YELLOW}4. DNS КОНФИГУРАЦИЯ:${NC}"
    echo "══════════════════════════════════════════"
    cat /etc/resolv.conf
    
    echo -e "\n${YELLOW}5. СЕТЕВЫЕ СОЕДИНЕНИЯ:${NC}"
    echo "══════════════════════════════════════════"
    ss -tulpn | head -20
    
    echo -e "\n${YELLOW}6. СЕТЕВАЯ СТАТИСТИКА:${NC}"
    echo "══════════════════════════════════════════"
    # Показываем статистику по всем интерфейсам
    for iface in $(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo); do
        echo -e "\nИнтерфейс $iface:"
        ip -s link show $iface | tail -4
    done
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 15: Тестирование соединения
test_connectivity() {
    echo -e "\n${GREEN}=== ТЕСТИРОВАНИЕ СОЕДИНЕНИЯ ===${NC}\n"
    
    echo -e "${YELLOW}Выберите тест:${NC}"
    echo "1. Быстрый тест (локальная сеть и интернет)"
    echo "2. Расширенный тест (все интерфейсы)"
    echo "3. Тест DNS разрешения"
    echo "4. Тест скорости соединения"
    echo "5. Трассировка маршрута"
    read -p "Выберите опцию [1-5]: " test_option
    
    case $test_option in
        1)
            echo -e "\n${YELLOW}Быстрый тест соединения:${NC}"
            echo "══════════════════════════════════════════"
            
            # Тест локального интерфейса
            echo -e "\n1. Тест локального интерфейса (lo):"
            ping -c 2 -W 1 127.0.0.1 && echo -e "${GREEN}✓ Локальный интерфейс работает${NC}" || echo -e "${RED}✗ Проблема с локальным интерфейсом${NC}"
            
            # Тест шлюза по умолчанию
            gateway=$(ip route show default | awk '/default/ {print $3}')
            if [[ -n $gateway ]]; then
                echo -e "\n2. Тест шлюза ($gateway):"
                ping -c 2 -W 1 $gateway && echo -e "${GREEN}✓ Шлюз доступен${NC}" || echo -e "${RED}✗ Шлюз не доступен${NC}"
            else
                echo -e "\n${RED}✗ Шлюз по умолчанию не настроен${NC}"
            fi
            
            # Тест DNS
            echo -e "\n3. Тест DNS (google.com):"
            if ping -c 2 -W 1 google.com 2>/dev/null; then
                echo -e "${GREEN}✓ DNS и интернет работают${NC}"
            else
                echo -e "\n4. Тест DNS через IP (8.8.8.8):"
                if ping -c 2 -W 1 8.8.8.8; then
                    echo -e "${YELLOW}⚠ Интернет работает, но DNS не разрешает имена${NC}"
                else
                    echo -e "${RED}✗ Нет доступа в интернет${NC}"
                fi
            fi
            ;;
        
        2)
            echo -e "\n${YELLOW}Расширенный тест всех интерфейсов:${NC}"
            echo "══════════════════════════════════════════"
            
            # Тестируем каждый интерфейс
            for iface in $(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v lo); do
                echo -e "\nИнтерфейс: $iface"
                
                # Получаем IP интерфейса
                ip_addr=$(ip addr show $iface | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
                
                if [[ -n $ip_addr ]]; then
                    echo "IP: $ip_addr"
                    
                    # Пинг самого себя
                    if ping -c 1 -W 1 $ip_addr >/dev/null 2>&1; then
                        echo -e "${GREEN}✓ Интерфейс отвечает${NC}"
                    else
                        echo -e "${RED}✗ Интерфейс не отвечает${NC}"
                    fi
                    
                    # Пинг шлюза для этой подсети
                    gateway=$(ip route show | grep $iface | grep default | awk '{print $3}')
                    if [[ -n $gateway && $gateway != $ip_addr ]]; then
                        echo "Тест шлюза: $gateway"
                        ping -c 1 -W 1 $gateway >/dev/null 2>&1 && \
                            echo -e "${GREEN}✓ Шлюз доступен${NC}" || \
                            echo -e "${RED}✗ Шлюз не доступен${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠ Нет IP адреса${NC}"
                fi
            done
            ;;
        
        3)
            echo -e "\n${YELLOW}Тест DNS разрешения:${NC}"
            echo "══════════════════════════════════════════"
            
            dns_servers=$(grep nameserver /etc/resolv.conf | awk '{print $2}')
            
            echo "Настроенные DNS серверы:"
            echo "$dns_servers"
            
            echo -e "\nТестируем разрешение имен:"
            for server in $dns_servers; do
                echo -e "\nDNS сервер: $server"
                if nslookup google.com $server 2>/dev/null | grep -q "Address:"; then
                    echo -e "${GREEN}✓ Работает${NC}"
                else
                    echo -e "${RED}✗ Не отвечает${NC}"
                fi
            done
            
            echo -e "\nПрямое разрешение:"
            for host in google.com ubuntu.com 8.8.8.8; do
                echo -n "$host: "
                if host $host >/dev/null 2>&1; then
                    echo -e "${GREEN}✓ Разрешается${NC}"
                else
                    echo -e "${RED}✗ Не разрешается${NC}"
                fi
            done
            ;;
        
        4)
            echo -e "\n${YELLOW}Тест скорости соединения:${NC}"
            echo "══════════════════════════════════════════"
            
            # Проверяем установлен ли iperf3
            if ! command -v iperf3 &> /dev/null; then
                echo "Установка iperf3 для тестирования скорости..."
                apt update
                apt install -y iperf3
            fi
            
            echo "Выберите тип теста:"
            echo "1. Тест загрузки (download)"
            echo "2. Тест отдачи (upload)"
            echo "3. Полный тест"
            read -p "Выберите [1-3]: " speed_test
            
            echo -e "\n${YELLOW}Тестируем скорость до публичного сервера iperf...${NC}"
            echo "Это может занять некоторое время..."
            
            case $speed_test in
                1)
                    iperf3 -c speedtest.serverius.net -p 5002 -R | tail -10
                    ;;
                2)
                    iperf3 -c speedtest.serverius.net -p 5002 | tail -10
                    ;;
                3)
                    echo -e "\nТест отдачи:"
                    iperf3 -c speedtest.serverius.net -p 5002 | tail -5
                    echo -e "\nТест загрузки:"
                    iperf3 -c speedtest.serverius.net -p 5002 -R | tail -5
                    ;;
                *)
                    echo "Неверный выбор"
                    ;;
            esac
            ;;
        
        5)
            echo -e "\n${YELLOW}Трассировка маршрута:${NC}"
            echo "══════════════════════════════════════════"
            
            read -p "Введите хост для трассировки [google.com]: " trace_host
            trace_host=${trace_host:-"google.com"}
            
            # Проверяем установлен ли traceroute
            if ! command -v traceroute &> /dev/null; then
                echo "Установка traceroute..."
                apt update
                apt install -y traceroute
            fi
            
            echo "Выполняем трассировку до $trace_host..."
            traceroute -n -w 1 -q 1 -m 15 $trace_host 2>/dev/null || \
                echo "Трассировка не удалась. Проверьте соединение."
            ;;
        
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Основной цикл программы
main() {
    check_root
    
    # Проверяем, что система Ubuntu
    if ! grep -q "Ubuntu" /etc/os-release; then
        echo -e "${RED}Внимание: Этот скрипт разработан для Ubuntu Server${NC}"
        read -p "Продолжить? (y/N): " continue_choice
        if [[ $continue_choice != "y" && $continue_choice != "Y" ]]; then
            exit 1
        fi
    fi
    
    while true; do
        show_menu
        read choice
        
        case $choice in
            1) full_diagnostic ;;
            2) setup_isc_dhcp ;;
            3) setup_dnsmasq ;;
            4) fix_ip_address ;;
            5) show_dhcp_logs ;;
            6) check_dhcp_clients ;;
            7) monitor_dhcp_traffic ;;
            8) reset_network_default ;;
            9) backup_configs ;;
            10) restore_backup ;;
            11) install_dhcp_server ;;
            12) restart_network_services ;;
            13) setup_static_ip ;;
            14) show_network_config ;;
            15) test_connectivity ;;
            16)
                echo -e "\n${GREEN}Выход...${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Неверный выбор!${NC}"
                sleep 2
                ;;
        esac
    done
}

# Запуск основной программы
main