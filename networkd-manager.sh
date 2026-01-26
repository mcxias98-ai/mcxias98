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
    echo -e "${BLUE}║${NC} 19. Выход                                             ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -n "Выберите опцию [1-19]: "
}

# Функция для проверки прав суперпользователя
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Этот скрипт должен запускаться с правами root!${NC}"
        echo "Используйте: sudo $0"
        exit 1
    fi
}

# Функция 1: Полная диагностика (обновленная)
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
    
    # Проверка systemd-networkd
    if systemctl is-active systemd-networkd >/dev/null 2>&1; then
        echo -e "systemd-networkd: ${GREEN}АКТИВЕН${NC}"
        systemctl status systemd-networkd --no-pager -l | head -10
    else
        echo -e "systemd-networkd: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
    
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
    
    # Проверка портов
    echo -e "${YELLOW}6. ОТКРЫТЫЕ ПОРТЫ DHCP (67,68):${NC}"
    echo "══════════════════════════════════════════"
    ss -tulpn | grep -E ':67|:68' | grep -v "127.0.0.1"
    echo ""
    
    # Конфигурационные файлы
    echo -e "${YELLOW}7. КОНФИГУРАЦИОННЫЕ ФАЙЛЫ:${NC}"
    echo "══════════════════════════════════════════"
    
    # Netplan
    if [[ -f "/etc/netplan/"* ]]; then
        echo "Netplan конфиги:"
        ls -la /etc/netplan/
        for file in /etc/netplan/*.yaml; do
            echo -e "\nФайл: $file"
            cat "$file" 2>/dev/null || echo "Не удалось прочитать"
        done
    fi
    echo ""
    
    # systemd-networkd
    if [[ -d "$NETWORKD_DIR" ]]; then
        echo "Конфиги systemd-networkd:"
        ls -la $NETWORKD_DIR/
        for file in $NETWORKD_DIR/*.network; do
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
    echo -e "${YELLOW}8. ПОСЛЕДНИЕ ЛОГИ DHCP:${NC}"
    echo "══════════════════════════════════════════"
    journalctl -u systemd-networkd -n 10 --no-pager 2>/dev/null
    journalctl -u isc-dhcp-server -n 10 --no-pager 2>/dev/null || \
    journalctl -u dnsmasq -n 10 --no-pager 2>/dev/null || \
    echo "Логи DHCP не найдены"
    echo ""
    
    # Проверка leases (systemd-networkd)
    echo -e "${YELLOW}9. АРЕНДЫ DHCP (systemd-networkd):${NC}"
    echo "══════════════════════════════════════════"
    if [[ -d "/run/systemd/netif/leases" ]]; then
        echo "Активные аренды systemd-networkd:"
        cat /run/systemd/netif/leases/*
    else
        echo "Аренды systemd-networkd не найдены"
    fi
    echo ""
    
    # Проверка leases (isc-dhcp-server и dnsmasq)
    echo -e "${YELLOW}10. АРЕНДЫ ДРУГИХ DHCP СЕРВЕРОВ:${NC}"
    echo "══════════════════════════════════════════"
    if [[ -f "/var/lib/dhcp/dhcpd.leases" ]]; then
        echo "Активные аренды isc-dhcp-server:"
        grep -E "lease|starts|ends|hardware" /var/lib/dhcp/dhcpd.leases | tail -20
    elif [[ -f "/var/lib/misc/dnsmasq.leases" ]]; then
        echo "Аренды dnsmasq:"
        cat /var/lib/misc/dnsmasq.leases
    else
        echo "Файлы аренд не найдены"
    fi
    echo ""
    
    # D-Bus информация о сети
    echo -e "${YELLOW}11. ИНФОРМАЦИЯ ЧЕРЕЗ NETWORKCTL:${NC}"
    echo "══════════════════════════════════════════"
    networkctl list
    echo ""
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 4: Настройка DHCP через systemd-networkd
setup_systemd_networkd_dhcp() {
    echo -e "\n${GREEN}=== НАСТРОЙКА DHCP СЕРВЕРА (SYSTEMD-NETWORKD) ===${NC}\n"
    
    echo -e "${YELLOW}systemd-networkd имеет встроенный DHCP сервер!${NC}"
    echo "Он может работать одновременно как DHCP клиент и сервер на разных интерфейсах"
    echo ""
    
    read -p "Введите имя интерфейса для сервера [$DEFAULT_INTERFACE]: " interface
    interface=${interface:-$DEFAULT_INTERFACE}
    
    echo -e "\n${YELLOW}Выберите режим:${NC}"
    echo "1. Только DHCP сервер (раздача адресов клиентам)"
    echo "2. DHCP сервер + статический IP на интерфейсе"
    echo "3. DHCP сервер + DHCP клиент (редко используется)"
    read -p "Выберите опцию [1-3]: " mode_choice
    
    read -p "Введите подсеть для раздачи [192.168.10.0/24]: " subnet
    subnet=${subnet:-"192.168.10.0/24"}
    
    read -p "Введите диапазон DHCP [$DEFAULT_DHCP_RANGE_START-$DEFAULT_DHCP_RANGE_END]: " dhcp_range
    dhcp_range=${dhcp_range:-"$DEFAULT_DHCP_RANGE_START-$DEFAULT_DHCP_RANGE_END"}
    
    read -p "Введите шлюз по умолчанию [192.168.10.1]: " gateway
    gateway=${gateway:-"192.168.10.1"}
    
    read -p "Введите DNS серверы [8.8.8.8 8.8.4.4]: " dns_servers
    dns_servers=${dns_servers:-"8.8.8.8 8.8.4.4"}
    
    # Создаем директорию если не существует
    mkdir -p $NETWORKD_DIR
    
    case $mode_choice in
        1)
            # Только DHCP сервер
            echo -e "\n${YELLOW}Создаем конфигурацию только DHCP сервера...${NC}"
            
            cat > $NETWORKD_DIR/10-$interface.network << EOF
[Match]
Name=$interface

[Network]
Address=$subnet
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=100
DNS=$dns_servers
EmitDNS=yes
EmitRouter=yes
EOF
            
            echo "Конфигурация создана: $NETWORKD_DIR/10-$interface.network"
            ;;
            
        2)
            # DHCP сервер + статический IP
            read -p "Введите статический IP для сервера [$gateway]: " static_ip
            static_ip=${static_ip:-$gateway}
            
            echo -e "\n${YELLOW}Создаем конфигурацию DHCP сервера со статическим IP...${NC}"
            
            cat > $NETWORKD_DIR/10-$interface.network << EOF
[Match]
Name=$interface

[Network]
Address=$static_ip/24
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=100
DNS=$dns_servers
EmitDNS=yes
EmitRouter=yes
EOF
            
            echo "Конфигурация создана: $NETWORKD_DIR/10-$interface.network"
            ;;
            
        3)
            # DHCP сервер + DHCP клиент (редкий случай)
            echo -e "\n${YELLOW}Создаем конфигурацию DHCP сервера и клиента...${NC}"
            echo "${RED}Внимание: Эта конфигурация может вызвать конфликты!${NC}"
            
            cat > $NETWORKD_DIR/10-$interface.network << EOF
[Match]
Name=$interface

[Network]
DHCP=yes
DHCPServer=yes

[DHCPServer]
PoolOffset=100
PoolSize=100
DNS=$dns_servers
EmitDNS=yes
EmitRouter=yes
EOF
            
            echo "Конфигурация создана: $NETWORKD_DIR/10-$interface.network"
            ;;
            
        *)
            echo "Неверный выбор"
            return
            ;;
    esac
    
    # Отключаем другие DHCP серверы на этом интерфейсе
    echo -e "\n${YELLOW}Отключаем другие DHCP серверы...${NC}"
    systemctl stop isc-dhcp-server 2>/dev/null
    systemctl stop dnsmasq 2>/dev/null
    
    # Останавливаем netplan если он используется
    if [[ -f /etc/netplan/*.yaml ]]; then
        echo "Обнаружен netplan. Создаем минимальную конфигурацию..."
        cat > /etc/netplan/01-systemd-networkd.yaml << EOF
network:
  version: 2
  renderer: networkd
EOF
        netplan apply
    fi
    
    # Включаем и запускаем systemd-networkd
    echo -e "\n${YELLOW}Запускаем systemd-networkd...${NC}"
    systemctl enable systemd-networkd
    systemctl restart systemd-networkd
    
    # Проверяем статус
    echo -e "\n${GREEN}Статус systemd-networkd:${NC}"
    systemctl status systemd-networkd --no-pager -l | head -10
    
    echo -e "\n${GREEN}Конфигурация интерфейса $interface:${NC}"
    networkctl status $interface
    
    echo -e "\n${YELLOW}Проверяем DHCP сервер:${NC}"
    networkctl status
    
    read -p "Нажмите Enter для продолжения..."
}

# Функция 9: Управление systemd-networkd
manage_systemd_networkd() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ SYSTEMD-NETWORKD ===${NC}\n"
    
    echo -e "${YELLOW}Выберите действие:${NC}"
    echo "1. Показать статус systemd-networkd"
    echo "2. Перезапустить systemd-networkd"
    echo "3. Перезагрузить конфигурацию"
    echo "4. Показать все сетевые устройства"
    echo "5. Показать подробности интерфейса"
    echo "6. Обновить DHCP аренды"
    echo "7. Сбросить конфигурацию сети"
    echo "8. Включить/отключить systemd-networkd"
    echo "9. Показать ленты событий (journal)"
    echo "10. Проверить синтаксис конфигурационных файлов"
    read -p "Выберите опцию [1-10]: " networkd_option
    
    case $networkd_option in
        1)
            echo -e "\n${YELLOW}Статус systemd-networkd:${NC}"
            systemctl status systemd-networkd --no-pager -l
            ;;
            
        2)
            echo -e "\n${YELLOW}Перезапускаем systemd-networkd...${NC}"
            systemctl restart systemd-networkd
            echo -e "${GREEN}Перезапуск выполнен${NC}"
            ;;
            
        3)
            echo -e "\n${YELLOW}Перезагружаем конфигурацию...${NC}"
            networkctl reload
            echo -e "${GREEN}Конфигурация перезагружена${NC}"
            ;;
            
        4)
            echo -e "\n${YELLOW}Все сетевые устройства:${NC}"
            networkctl list
            ;;
            
        5)
            read -p "Введите имя интерфейса [$DEFAULT_INTERFACE]: " interface
            interface=${interface:-$DEFAULT_INTERFACE}
            
            echo -e "\n${YELLOW}Подробности интерфейса $interface:${NC}"
            networkctl status $interface --no-pager -l
            ;;
            
        6)
            echo -e "\n${YELLOW}Обновляем DHCP аренды...${NC}"
            networkctl renew
            echo -e "${GREEN}DHCP аренды обновлены${NC}"
            ;;
            
        7)
            echo -e "\n${RED}СБРОС КОНФИГУРАЦИИ СЕТИ${NC}"
            echo "Это удалит все конфигурационные файлы systemd-networkd!"
            read -p "Вы уверены? (y/N): " confirm
            if [[ $confirm == "y" || $confirm == "Y" ]]; then
                rm -f $NETWORKD_DIR/*.network
                rm -f $NETWORKD_DIR/*.link
                rm -f $NETWORKD_DIR/*.netdev
                systemctl restart systemd-networkd
                echo -e "${GREEN}Конфигурация сброшена${NC}"
            fi
            ;;
            
        8)
            if systemctl is-enabled systemd-networkd >/dev/null 2>&1; then
                echo -e "\n${YELLOW}systemd-networkd включен. Выберите действие:${NC}"
                echo "1. Отключить systemd-networkd"
                echo "2. Остановить systemd-networkd"
                echo "3. Отключить и остановить"
                read -p "Выберите опцию [1-3]: " disable_choice
                
                case $disable_choice in
                    1) systemctl disable systemd-networkd ;;
                    2) systemctl stop systemd-networkd ;;
                    3) 
                        systemctl disable systemd-networkd
                        systemctl stop systemd-networkd
                        ;;
                esac
            else
                echo -e "\n${YELLOW}systemd-networkd отключен. Включить? (y/N):${NC}"
                read -p "Выберите: " enable_choice
                if [[ $enable_choice == "y" || $enable_choice == "Y" ]]; then
                    systemctl enable systemd-networkd
                    systemctl start systemd-networkd
                fi
            fi
            ;;
            
        9)
            echo -e "\n${YELLOW}Ленты событий systemd-networkd:${NC}"
            echo "1. Последние 50 сообщений"
            echo "2. Сообщения за последний час"
            echo "3. Сообщения об ошибках"
            echo "4. Мониторинг в реальном времени"
            read -p "Выберите опцию [1-4]: " journal_choice
            
            case $journal_choice in
                1) journalctl -u systemd-networkd -n 50 --no-pager ;;
                2) journalctl -u systemd-networkd --since "1 hour ago" --no-pager ;;
                3) journalctl -u systemd-networkd -p err --no-pager ;;
                4) 
                    echo -e "${YELLOW}Мониторинг в реальном времени (Ctrl+C для выхода):${NC}"
                    journalctl -u systemd-networkd -f
                    ;;
            esac
            ;;
            
        10)
            echo -e "\n${YELLOW}Проверка синтаксиса конфигурационных файлов:${NC}"
            if command -v networkd-dispatcher &> /dev/null; then
                networkd-dispatcher --test
            else
                echo "Проверяем файлы вручную..."
                for file in $NETWORKD_DIR/*.network $NETWORKD_DIR/*.link $NETWORKD_DIR/*.netdev; do
                    if [[ -f $file ]]; then
                        echo "Проверка $file:"
                        if [[ $file == *.network ]] && grep -q "\[" $file; then
                            echo -e "  ${GREEN}✓ Корректный INI-формат${NC}"
                        else
                            echo -e "  ${YELLOW}⚠ Возможные проблемы${NC}"
                        fi
                    fi
                done
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
    
    if [[ ! -d $NETWORKD_DIR ]]; then
        echo -e "${YELLOW}Директория systemd-networkd не найдена${NC}"
        echo "systemd-networkd, вероятно, не используется или не установлен"
        return
    fi
    
    echo -e "${YELLOW}Содержимое $NETWORKD_DIR:${NC}"
    ls -la $NETWORKD_DIR/
    
    echo -e "\n${YELLOW}Файлы .network:${NC}"
    for file in $NETWORKD_DIR/*.network; do
        if [[ -f $file ]]; then
            echo -e "\n${CYAN}=== $(basename $file) ===${NC}"
            cat "$file"
            echo "${CYAN}=================================${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}Файлы .link:${NC}"
    for file in $NETWORKD_DIR/*.link; do
        if [[ -f $file ]]; then
            echo -e "\n${CYAN}=== $(basename $file) ===${NC}"
            cat "$file"
            echo "${CYAN}=================================${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}Файлы .netdev:${NC}"
    for file in $NETWORKD_DIR/*.netdev; do
        if [[ -f $file ]]; then
            echo -e "\n${CYAN}=== $(basename $file) ===${NC}"
            cat "$file"
            echo "${CYAN}=================================${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}Текущее состояние через networkctl:${NC}"
    networkctl list
    
    echo -e "\n${YELLOW}Активные аренды DHCP:${NC}"
    if [[ -d "/run/systemd/netif/leases" ]]; then
        for lease_file in /run/systemd/netif/leases/*; do
            if [[ -f $lease_file ]]; then
                echo -e "\n${CYAN}=== $(basename $lease_file) ===${NC}"
                cat "$lease_file"
            fi
        done
    else
        echo "Файлы аренд не найдены"
    fi
    
    echo -e "\n${YELLOW}Статистика systemd-networkd:${NC}"
    systemctl status systemd-networkd --no-pager -l | grep -A5 "Loaded:"
    
    read -p "Нажмите Enter для продолжения..."
}

# Обновленная функция резервного копирования
backup_configs() {
    echo -e "\n${GREEN}=== РЕЗЕРВНОЕ КОПИРОВАНИЕ КОНФИГУРАЦИЙ ===${NC}\n"
    
    backup_dir="/root/network_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p $backup_dir
    
    echo "Создаем резервную копию в $backup_dir..."
    
    # Копируем конфигурационные файлы (добавлен systemd-networkd)
    files_to_backup=(
        "/etc/netplan/"
        "/etc/dhcp/"
        "/etc/dnsmasq.conf"
        "/etc/default/isc-dhcp-server"
        "/etc/hostname"
        "/etc/hosts"
        "/etc/resolv.conf"
        "/var/lib/dhcp/dhcpd.leases"
        "$NETWORKD_DIR/"
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
    networkctl list > $backup_dir/networkctl_list.txt 2>/dev/null
    
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
cp -r systemd/network/* /etc/systemd/network/ 2>/dev/null
cp dhcpd.conf /etc/dhcp/ 2>/dev/null
cp dnsmasq.conf /etc/ 2>/dev/null
cp isc-dhcp-server /etc/default/ 2>/dev/null
cp dhcpd.leases /var/lib/dhcp/ 2>/dev/null

# Применяем настройки
netplan apply
systemctl restart systemd-networkd

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

# Обновленная функция установки DHCP сервера
install_dhcp_server() {
    echo -e "\n${GREEN}=== УСТАНОВКА/ПЕРЕУСТАНОВКА DHCP СЕРВЕРА ===${NC}\n"
    
    echo -e "${YELLOW}Выберите DHCP сервер:${NC}"
    echo "1. isc-dhcp-server (стандартный, больше настроек)"
    echo "2. dnsmasq (проще, легче, включает DNS)"
    echo "3. systemd-networkd (встроенный, минималистичный)"
    echo "4. Удалить все DHCP серверы"
    echo "5. Установить все доступные"
    read -p "Выберите опцию [1-5]: " install_option
    
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
            echo -e "\n${YELLOW}Установка systemd-networkd...${NC}"
            echo "systemd-networkd обычно предустановлен в Ubuntu Server"
            
            apt update
            apt install -y systemd networkd-dispatcher
            
            echo -e "\n${GREEN}Проверяем установку:${NC}"
            systemctl status systemd-networkd --no-pager -l | head -10
            
            echo "Используйте опцию 4 в главном меню для настройки DHCP сервера."
            ;;
        4)
            echo -e "\n${YELLOW}Удаление всех DHCP серверов...${NC}"
            apt remove -y isc-dhcp-server dnsmasq
            apt autoremove -y
            
            echo "Очищаем конфигурационные файлы..."
            rm -rf /etc/dhcp/
            rm -f /etc/dnsmasq.conf
            rm -f /etc/default/isc-dhcp-server
            rm -rf $NETWORKD_DIR/*
            
            echo -e "\n${GREEN}Все DHCP серверы удалены!${NC}"
            ;;
        5)
            echo -e "\n${YELLOW}Установка всех доступных DHCP серверов...${NC}"
            apt update
            apt install -y isc-dhcp-server dnsmasq systemd networkd-dispatcher
            
            echo -e "\n${GREEN}Установка завершена!${NC}"
            echo "Внимание: Серверы не могут работать одновременно на одних портах!"
            echo "Отключите ненужные серверы перед использованием."
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac
    
    read -p "Нажмите Enter для продолжения..."
}

# Основной цикл программы (обновленный)
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
            19)
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