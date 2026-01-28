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
IPTABLES_BACKUP="/root/iptables_backup_$(date +%Y%m%d_%H%M%S)"

# ==================== ОБЩИЕ ФУНКЦИИ ====================

# Функция для проверки прав суперпользователя
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}Ошибка: Этот скрипт должен запускаться с правами root!${NC}"
        echo "Используйте: sudo $0"
        exit 1
    fi
}

# Функция для очистки экрана
clear_screen() {
    clear || printf "\033c"
}

# Функция ожидания нажатия Enter
wait_for_enter() {
    echo -e "\n${YELLOW}────────────────────────────────────────────${NC}"
    read -p "Нажмите Enter для продолжения..."
}

# Функция выбора интерфейса
select_interface() {
    local prompt_text="${1:-Выберите сетевой интерфейс:}"
    
    echo -e "\n${YELLOW}$prompt_text${NC}"
    echo "══════════════════════════════════════════"
    
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
        read -p "Введите номер [1-${#interfaces[@]}] (или 0 для ручного ввода): " choice

        if [[ "$choice" =~ ^[0-9]+$ ]]; then
            if [ "$choice" -eq 0 ]; then
                read -p "Введите имя интерфейса вручную: " interface
                if ip link show "$interface" &>/dev/null; then
                    echo "$interface"
                    return 0
                else
                    echo -e "${RED}Интерфейс '$interface' не найден!${NC}"
                fi
            elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#interfaces[@]} ]; then
                echo "${interfaces[$((choice-1))]}"
                return 0
            else
                echo -e "${RED}Неверный номер! Пожалуйста, выберите от 0 до ${#interfaces[@]}${NC}"
            fi
        else
            echo -e "${RED}Введите число!${NC}"
        fi
    done
}

# Функция проверки установки UFW
check_install_ufw() {
    if ! command -v ufw &> /dev/null; then
        read -p "UFW не установлен. Установить? (y/N): " install_ufw
        if [[ $install_ufw == "y" || $install_ufw == "Y" ]]; then
            apt update && apt install -y ufw
            return $?
        else
            echo -e "${RED}UFW не установлен. Пропускаем настройку.${NC}"
            return 1
        fi
    fi
    return 0
}

# ==================== МЕНЮ И ПОДМЕНЮ ====================

# Функция для отображения главного меню
show_menu() {
    clear_screen
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         DHCP Server Manager - Ubuntu Server 24.04                             ║${NC}"
    echo -e "${BLUE}╠═══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} 1.  Диагностика и мониторинг                                      ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 2.  Настройка DHCP серверов                                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 3.  Управление сетевыми интерфейсами                              ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 4.  Управление системными службами                                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 5.  Резервное копирование и восстановление                        ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 6.  Безопасность и брандмауэр                                     ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 7.  Маршрутизация и пересылка пакетов                             ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC} 8.  Выход                                                         ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -n "Выберите опцию [1-8]: "
}

# ==================== ПОДМЕНЮ 1: ДИАГНОСТИКА И МОНИТОРИНГ ====================

show_diagnostic_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== ДИАГНОСТИКА И МОНИТОРИНГ ===${NC}\n"
        
        echo "1.  Полная диагностика сети и DHCP сервера"
        echo "2.  Показать логи DHCP сервера"
        echo "3.  Проверить клиентов DHCP (аренды)"
        echo "4.  Мониторинг DHCP трафика в реальном времени"
        echo "5.  Показать текущую конфигурацию сети"
        echo "6.  Тестирование соединения"
        echo "7.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-7]: "
        
        read choice
        
        case $choice in
            1) full_diagnostic ;;
            2) show_dhcp_logs ;;
            3) check_dhcp_clients ;;
            4) monitor_dhcp_traffic ;;
            5) show_network_config ;;
            6) test_connectivity ;;
            7) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ПОДМЕНЮ 2: НАСТРОЙКА DHCP СЕРВЕРОВ ====================

show_dhcp_setup_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== НАСТРОЙКА DHCP СЕРВЕРОВ ===${NC}\n"
        
        echo "1.  Настроить DHCP сервер (isc-dhcp-server)"
        echo "2.  Настроить DHCP сервер (dnsmasq - проще)"
        echo "3.  Настроить DHCP сервер (systemd-networkd)"
        echo "4.  Установить/переустановить DHCP сервер"
        echo "5.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-5]: "
        
        read choice
        
        case $choice in
            1) setup_isc_dhcp ;;
            2) setup_dnsmasq ;;
            3) setup_systemd_networkd_dhcp ;;
            4) install_dhcp_server ;;
            5) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ПОДМЕНЮ 3: УПРАВЛЕНИЕ СЕТЕВЫМИ ИНТЕРФЕЙСАМИ ====================

show_interface_management_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== УПРАВЛЕНИЕ СЕТЕВЫМИ ИНТЕРФЕЙСАМИ ===${NC}\n"
        
        echo "1.  Проверить и исправить IP адрес на интерфейсе"
        echo "2.  Настроить статический IP на интерфейсе"
        echo "3.  Управление переименованием сетевых интерфейсов"
        echo "4.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-4]: "
        
        read choice
        
        case $choice in
            1) fix_ip_address ;;
            2) setup_static_ip ;;
            3) manage_interface_renaming ;;
            4) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ПОДМЕНЮ 4: УПРАВЛЕНИЕ СИСТЕМНЫМИ СЛУЖБАМИ ====================

show_services_management_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== УПРАВЛЕНИЕ СИСТЕМНЫМИ СЛУЖБАМИ ===${NC}\n"
        
        echo "1.  Управление systemd-networkd"
        echo "2.  Просмотр конфигурации systemd-networkd"
        echo "3.  Перезапустить сетевые службы"
        echo "4.  Сбросить все сетевые настройки по умолчанию"
        echo "5.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-5]: "
        
        read choice
        
        case $choice in
            1) manage_systemd_networkd ;;
            2) view_systemd_networkd_config ;;
            3) restart_network_services ;;
            4) reset_network_default ;;
            5) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ПОДМЕНЮ 5: РЕЗЕРВНОЕ КОПИРОВАНИЕ И ВОССТАНОВЛЕНИЕ ====================

show_backup_restore_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== РЕЗЕРВНОЕ КОПИРОВАНИЕ И ВОССТАНОВЛЕНИЕ ===${NC}\n"
        
        echo "1.  Резервное копирование сетевых конфигураций"
        echo "2.  Восстановить из резервной копии"
        echo "3.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-3]: "
        
        read choice
        
        case $choice in
            1) backup_configs ;;
            2) restore_backup ;;
            3) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ПОДМЕНЮ 6: БЕЗОПАСНОСТЬ И БРАНДМАУЭР ====================

show_security_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== БЕЗОПАСНОСТЬ И БРАНДМАУЭР ===${NC}\n"
        
        echo "1.  Управление UFW (брандмауэр)"
        echo "2.  Управление iptables (правила фаервола)"
        echo "3.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-3]: "
        
        read choice
        
        case $choice in
            1) manage_ufw ;;
            2) manage_iptables ;;
            3) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ПОДМЕНЮ 7: МАРШРУТИЗАЦИЯ И ПЕРЕСЫЛКА ПАКЕТОВ ====================

show_routing_submenu() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== МАРШРУТИЗАЦИЯ И ПЕРЕСЫЛКА ПАКЕТОВ ===${NC}\n"
        
        echo "1.  Управление IP Forwarding (перенаправление трафика)"
        echo "2.  Управление маршрутизацией (добавить/удалить маршруты)"
        echo "3.  Вернуться в главное меню"
        echo -n "Выберите опцию [1-3]: "
        
        read choice
        
        case $choice in
            1) manage_ip_forwarding ;;
            2) manage_routing ;;
            3) return 0 ;;
            *) echo "Неверный выбор" && sleep 1 ;;
        esac
    done
}

# ==================== ФУНКЦИИ ДИАГНОСТИКИ ====================

# Функция 1: Полная диагностика
full_diagnostic() {
    while true; do
        clear_screen
        echo -e "\n${GREEN}=== ПОЛНАЯ ДИАГНОСТИКА СЕТИ И DHCP СЕРВЕРА ===${NC}\n"

        echo "1.  СЕТЕВЫЕ ИНТЕРФЕЙСЫ"
        echo "2.  СОСТОЯНИЕ ИНТЕРФЕЙСОВ"
        echo "3.  ТАБЛИЦА МАРШРУТИЗАЦИИ"
        echo "4.  ARP ТАБЛИЦА"
        echo "5.  СЛУЖБЫ DHCP"
        echo "6.  ОТКРЫТЫЕ ПОРТЫ DHCP"
        echo "7.  КОНФИГУРАЦИОННЫЕ ФАЙЛЫ"
        echo "8.  ЛОГИ DHCP"
        echo "9.  АРЕНДЫ DHCP"
        echo "10. NETWORKCTL ИНФОРМАЦИЯ"
        echo "11. IP FORWARDING"
        echo "12. СОСТОЯНИЕ БРАНДМАУЭРА"
        echo "13. DNS И РАЗРЕШЕНИЕ ИМЕН"
        echo "14. ПРОВЕРКА СЕТЕВЫХ СОЕДИНЕНИЙ"
        echo "15. МОНИТОРИНГ ТРАФИКА В РЕАЛЬНОМ ВРЕМЕНИ"
        echo "16. ИНФОРМАЦИЯ О СЕТЕВЫХ УСТРОЙСТВАХ"
        echo "17. ПРОВЕРКА СЕТЕВОЙ ПРОПУСКНОЙ СПОСОБНОСТИ"
        echo "18. ДИАГНОСТИКА MTU"
        echo "19. СТАТИСТИКА СЕТЕВЫХ ИНТЕРФЕЙСОВ"
        echo "20. ПРОВЕРКА НАТ И МАРШРУТИЗАЦИИ"
        echo "21. ВЕРНУТЬСЯ В ПРЕДЫДУЩЕЕ МЕНЮ"
        echo -n "Выберите опцию [1-21]: "

        read diagnostic_option

        case $diagnostic_option in
            1)
                clear_screen
                echo -e "${YELLOW}Информация о сетевых интерфейсах и IP-адресах:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Подробная информация:${NC}"
                ip -c -br addr show
                echo -e "\n${CYAN}IPv4 адреса:${NC}"
                ip -4 -c addr show
                echo -e "\n${CYAN}IPv6 адреса:${NC}"
                ip -6 -c addr show 2>/dev/null || echo "IPv6 не настроен"
                wait_for_enter
                ;;
            2)
                clear_screen
                echo -e "${YELLOW}Состояние сетевых интерфейсов (UP/DOWN):${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Статус интерфейсов:${NC}"
                ip -c -br link show
                echo -e "\n${CYAN}Скорость и дуплекс:${NC}"
                for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
                    if command -v ethtool >/dev/null 2>&1; then
                        echo -n "$iface: "
                        ethtool $iface 2>/dev/null | grep -E "Speed|Duplex" | head -2 || echo "информация недоступна"
                    fi
                done
                echo -e "\n${CYAN}Статистика ошибок:${NC}"
                ip -s link show | grep -A3 "errors\|dropped"
                wait_for_enter
                ;;
            3)
                clear_screen
                echo -e "${YELLOW}Маршруты и шлюзы по умолчанию:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Таблица маршрутизации IPv4:${NC}"
                ip -4 -c route show
                echo -e "\n${CYAN}Таблица маршрутизации IPv6:${NC}"
                ip -6 -c route show 2>/dev/null || echo "Маршруты IPv6 не настроены"
                echo -e "\n${CYAN}Шлюзы по умолчанию:${NC}"
                ip route show default
                echo -e "\n${CYAN}Политика маршрутизации:${NC}"
                ip rule show
                wait_for_enter
                ;;
            4)
                clear_screen
                echo -e "${YELLOW}Таблица ARP (соответствие IP-MAC):${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}ARP таблица:${NC}"
                ip -c neigh show
                echo -e "\n${CYAN}Статистика ARP:${NC}"
                arp -an 2>/dev/null || echo "ARP недоступен"
                echo -e "\n${CYAN}MAC адреса интерфейсов:${NC}"
                ip -c link show | grep -E "link/ether|link/loopback"
                wait_for_enter
                ;;
            5)
                clear_screen
                echo -e "${YELLOW}Состояние DHCP сервисов:${NC}"
                echo "══════════════════════════════════════════"
                check_service_status "systemd-networkd"
                check_service_status "isc-dhcp-server"
                check_service_status "dnsmasq"
                check_service_status "dhcpd"
                echo -e "\n${CYAN}Проверка сокетов DHCP:${NC}"
                ss -tulpn | grep -E ':67|:68' | grep -v "127.0.0.1"
                wait_for_enter
                ;;
            6)
                clear_screen
                echo -e "${YELLOW}Проверка портов DHCP (67,68):${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Слушающие порты UDP 67/68:${NC}"
                ss -tulpn | grep -E ':67|:68' | grep -v "127.0.0.1" || echo "Порты не открыты"
                echo -e "\n${CYAN}Активные соединения DHCP:${NC}"
                ss -tupn | grep -E ':67|:68' || echo "Активных соединений нет"
                echo -e "\n${CYAN}Проверка с помощью netstat:${NC}"
                netstat -tulpn 2>/dev/null | grep -E ':67|:68' || echo "Netstat не доступен"
                echo -e "\n${CYAN}Проверка брандмауэра:${NC}"
                if command -v ufw >/dev/null 2>&1; then
                    ufw status | grep -E "67/udp|68/udp"
                fi
                wait_for_enter
                ;;
            7)
                clear_screen
                echo -e "${YELLOW}Сетевые конфигурационные файлы:${NC}"
                echo "══════════════════════════════════════════"
                show_config_files
                wait_for_enter
                ;;
            8)
                clear_screen
                echo -e "${YELLOW}Последние логи DHCP сервисов:${NC}"
                echo "══════════════════════════════════════════"
                show_service_logs
                wait_for_enter
                ;;
            9)
                clear_screen
                echo -e "${YELLOW}Активные аренды DHCP:${NC}"
                echo "══════════════════════════════════════════"
                show_dhcp_leases
                wait_for_enter
                ;;
            10)
                clear_screen
                echo -e "${YELLOW}Информация через networkctl:${NC}"
                echo "══════════════════════════════════════════"
                if which networkctl >/dev/null 2>&1; then
                    echo -e "${CYAN}Список интерфейсов:${NC}"
                    networkctl list 2>/dev/null || echo "Ошибка выполнения"
                    echo -e "\n${CYAN}Статус сети:${NC}"
                    networkctl status 2>/dev/null | head -30
                    echo -e "\n${CYAN}Статус LLDP:${NC}"
                    networkctl lldp 2>/dev/null || echo "LLDP не настроен"
                else
                    echo "networkctl не установлен"
                fi
                wait_for_enter
                ;;
            11)
                clear_screen
                echo -e "${YELLOW}Состояние пересылки пакетов:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}IPv4 Forwarding: ${NC}$(sysctl -n net.ipv4.ip_forward)"
                echo -e "${CYAN}IPv6 Forwarding: ${NC}$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || echo 'N/A')"
                echo -e "\n${CYAN}Текущие настройки sysctl:${NC}"
                sysctl -a 2>/dev/null | grep -E "ip_forward|forwarding" | head -15
                echo -e "\n${CYAN}Проверка правил iptables FORWARD:${NC}"
                iptables -L FORWARD -n -v 2>/dev/null | head -20
                wait_for_enter
                ;;
            12)
                clear_screen
                echo -e "${YELLOW}Проверка настроек брандмауэра:${NC}"
                echo "══════════════════════════════════════════"
                show_firewall_status
                wait_for_enter
                ;;
            13)
                clear_screen
                echo -e "${YELLOW}DNS И РАЗРЕШЕНИЕ ИМЕН:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Конфигурация DNS:${NC}"
                cat /etc/resolv.conf 2>/dev/null || echo "Файл не найден"
                echo -e "\n${CYAN}Проверка DNS серверов:${NC}"
                for dns in $(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | head -3); do
                    echo -n "DNS $dns: "
                    nslookup google.com $dns 2>/dev/null | grep -q "Address" && echo "OK" || echo "ERROR"
                done
                echo -e "\n${CYAN}Проверка локального разрешения имен:${NC}"
                grep -v "^#" /etc/hosts 2>/dev/null | head -10
                echo -e "\n${CYAN}Проверка доменных имен:${NC}"
                hostname -f 2>/dev/null && echo "FQDN: $(hostname -f)" || echo "FQDN не настроен"
                wait_for_enter
                ;;
            14)
                clear_screen
                echo -e "${YELLOW}ПРОВЕРКА СЕТЕВЫХ СОЕДИНЕНИЙ:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Пинг локального интерфейса:${NC}"
                ping -c 2 -W 1 127.0.0.1 2>/dev/null && echo "Локальный интерфейс: OK" || echo "Локальный интерфейс: ERROR"
                echo -e "\n${CYAN}Пинг шлюза по умолчанию:${NC}"
                gateway=$(ip route show default | awk '/default/ {print $3}')
                if [[ -n "$gateway" ]]; then
                    ping -c 2 -W 1 $gateway 2>/dev/null && echo "Шлюз $gateway: OK" || echo "Шлюз $gateway: ERROR"
                else
                    echo "Шлюз не настроен"
                fi
                echo -e "\n${CYAN}Пинг внешних ресурсов:${NC}"
                ping -c 2 -W 1 8.8.8.8 2>/dev/null && echo "Интернет (8.8.8.8): OK" || echo "Интернет (8.8.8.8): ERROR"
                echo -e "\n${CYAN}Traceroute до 8.8.8.8:${NC}"
                traceroute -n -m 5 8.8.8.8 2>/dev/null | head -10 || echo "Traceroute не доступен"
                wait_for_enter
                ;;
            15)
                clear_screen
                echo -e "${YELLOW}МОНИТОРИНГ ТРАФИКА В РЕАЛЬНОМ ВРЕМЕНИ:${NC}"
                echo "══════════════════════════════════════════"
                if ! command -v iftop >/dev/null 2>&1; then
                    echo "Установка iftop для мониторинга трафика..."
                    apt update && apt install -y iftop 2>/dev/null
                fi
                if command -v iftop >/dev/null 2>&1; then
                    interface=$(select_interface "Выберите интерфейс для мониторинга:")
                    [[ -n "$interface" ]] && iftop -i $interface -n -t -s 10
                else
                    echo "Для мониторинга установите iftop: apt install iftop"
                fi
                wait_for_enter
                ;;
            16)
                clear_screen
                echo -e "${YELLOW}ИНФОРМАЦИЯ О СЕТЕВЫХ УСТРОЙСТВАХ:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Информация о PCI устройствах:${NC}"
                lspci 2>/dev/null | grep -i "network\|ethernet" || echo "lspci не доступен"
                echo -e "\n${CYAN}Информация о USB сетевых адаптерах:${NC}"
                lsusb 2>/dev/null | grep -i "network\|ethernet" || echo "lsusb не доступен"
                echo -e "\n${CYAN}Загруженные сетевые модули:${NC}"
                lsmod | grep -E "eth|net|wireless|wlan" | head -20
                wait_for_enter
                ;;
            17)
                clear_screen
                echo -e "${YELLOW}ПРОВЕРКА СЕТЕВОЙ ПРОПУСКНОЙ СПОСОБНОСТИ:${NC}"
                echo "══════════════════════════════════════════"
                if ! command -v iperf3 >/dev/null 2>&1; then
                    echo "Установка iperf3 для проверки пропускной способности..."
                    apt update && apt install -y iperf3 2>/dev/null
                fi
                echo -e "${CYAN}Быстрая проверка:${NC}"
                echo "1. Проверить локальную пропускную способность"
                echo "2. Проверить соединение с внешним сервером"
                read -p "Выберите опцию [1-2]: " speed_option

                case $speed_option in
                    1)
                        echo "Запускаем локальный тест (требуется iperf3 сервер)..."
                        iperf3 -c localhost 2>/dev/null || echo "Запустите iperf3 сервер: iperf3 -s"
                        ;;
                    2)
                        echo "Тестируем скорость до публичного сервера..."
                        iperf3 -c speedtest.serverius.net -p 5002 -P 4 2>/dev/null | tail -10 || echo "Тест не удался"
                        ;;
                esac
                wait_for_enter
                ;;
            18)
                clear_screen
                echo -e "${YELLOW}ДИАГНОСТИКА MTU:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Текущие значения MTU:${NC}"
                ip link show | grep mtu
                echo -e "\n${CYAN}Проверка оптимального MTU:${NC}"
                interface=$(select_interface "Выберите интерфейс для проверки MTU:")
                if [[ -n "$interface" ]]; then
                    current_mtu=$(ip link show $interface | grep mtu | awk '{print $5}')
                    echo "Текущий MTU на $interface: $current_mtu"
                    echo -e "\nПроверка MTU пингом до 8.8.8.8:"
                    for size in 1472 1400 1300 1200; do
                        echo -n "MTU $size: "
                        ping -M do -s $size -c 1 8.8.8.8 2>/dev/null >/dev/null && echo "OK" || echo "FAIL"
                    done
                fi
                wait_for_enter
                ;;
            19)
                clear_screen
                echo -e "${YELLOW}СТАТИСТИКА СЕТЕВЫХ ИНТЕРФЕЙСОВ:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Общая статистика:${NC}"
                ip -s link show
                echo -e "\n${CYAN}Детальная статистика по интерфейсам:${NC}"
                for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v lo); do
                    echo -e "\n${YELLOW}Интерфейс: $iface${NC}"
                    ip -s -s link show $iface | tail -10
                done
                echo -e "\n${CYAN}Статистика ошибок:${NC}"
                netstat -i 2>/dev/null || echo "Netstat не доступен"
                wait_for_enter
                ;;
            20)
                clear_screen
                echo -e "${YELLOW}ПРОВЕРКА НАТ И МАРШРУТИЗАЦИИ:${NC}"
                echo "══════════════════════════════════════════"
                echo -e "${CYAN}Правила NAT:${NC}"
                iptables -t nat -L -n -v 2>/dev/null | head -30
                echo -e "\n${CYAN}Таблица маршрутизации ядра:${NC}"
                cat /proc/net/route 2>/dev/null | head -10
                echo -e "\n${CYAN}Проверка коннективности через NAT:${NC}"
                echo "Внутренний IP: $(hostname -I | awk '{print $1}')"
                echo "Внешний IP (если доступен): $(curl -s ifconfig.me 2>/dev/null || echo 'Не определен')"
                wait_for_enter
                ;;
            21)
                return 0
                ;;
            *)
                echo "Неверный выбор"
                sleep 1
                ;;
        esac
    done
}

# Вспомогательная функция для показа статуса службы
check_service_status() {
    local service=$1
    if systemctl is-active $service >/dev/null 2>&1; then
        echo -e "$service: ${GREEN}АКТИВЕН${NC}"
        systemctl status $service --no-pager -l | head -10
    else
        echo -e "$service: ${RED}НЕ АКТИВЕН${NC}"
    fi
    echo ""
}

# Вспомогательная функция для показа конфигурационных файлов
show_config_files() {
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

    [[ -f "/etc/dhcp/dhcpd.conf" ]] && echo "Конфиг isc-dhcp-server (/etc/dhcp/dhcpd.conf):" && head -20 /etc/dhcp/dhcpd.conf
    [[ -f "/etc/default/isc-dhcp-server" ]] && echo -e "\nИнтерфейсы isc-dhcp-server:" && cat /etc/default/isc-dhcp-server
    [[ -f "/etc/dnsmasq.conf" ]] && echo -e "\nКонфиг dnsmasq (первые 20 строк):" && head -20 /etc/dnsmasq.conf
}

# Вспомогательная функция для показа логов
show_service_logs() {
    echo "Последние 10 записей systemd-networkd:"
    journalctl -u systemd-networkd -n 10 --no-pager 2>/dev/null || echo "Логи недоступны"
    echo ""
    echo "Последние 10 записей isc-dhcp-server:"
    journalctl -u isc-dhcp-server -n 10 --no-pager 2>/dev/null || echo "Логи недоступны"
    echo ""
    echo "Последние 10 записей dnsmasq:"
    journalctl -u dnsmasq -n 10 --no-pager 2>/dev/null || echo "Логи недоступны"
}

# Вспомогательная функция для показа аренд DHCP
show_dhcp_leases() {
    if [[ -d "/run/systemd/netif/leases" ]]; then
        echo "Активные аренды systemd-networkd:"
        ls -la /run/systemd/netif/leases/ 2>/dev/null
        for lease in /run/systemd/netif/leases/*; do
            [[ -f "$lease" ]] && echo -e "\nФайл: $(basename "$lease")" && cat "$lease"
        done 2>/dev/null
    else
        echo "Аренды systemd-networkd не найдены"
    fi

    echo -e "\n${YELLOW}Аренды isc-dhcp-server:${NC}"
    if [[ -f "/var/lib/dhcp/dhcpd.leases" ]]; then
        echo "Последние аренды:"
        tail -20 /var/lib/dhcp/dhcpd.leases 2>/dev/null || echo "Не удалось прочитать"
    else
        echo "Файл аренд не найден"
    fi
}

# Вспомогательная функция для показа статуса фаервола
show_firewall_status() {
    echo "UFW (Uncomplicated Firewall):"
    if command -v ufw &> /dev/null; then
        ufw status verbose | head -5
    else
        echo "UFW не установлен"
    fi

    echo -e "\nIPTABLES - Цепочки правил:"
    echo "────────────────────────────────"
    echo "Цепочка INPUT:"
    iptables -L INPUT -n --line-numbers 2>/dev/null | head -20 || echo "Ошибка чтения iptables"

    echo -e "\nЦепочка FORWARD:"
    iptables -L FORWARD -n --line-numbers 2>/dev/null | head -20 || echo "Ошибка чтения iptables"

    echo -e "\nЦепочка OUTPUT:"
    iptables -L OUTPUT -n --line-numbers 2>/dev/null | head -20 || echo "Ошибка чтения iptables"

    if command -v nft &> /dev/null; then
        echo -e "\nNFTABLES:"
        nft list ruleset 2>/dev/null | head -30 || echo "Ошибка чтения nftables"
    fi
}

# ==================== ФУНКЦИИ DHCP СЕРВЕРОВ ====================

# Функция настройки isc-dhcp-server
setup_isc_dhcp() {
    echo -e "\n${GREEN}=== НАСТРОЙКА ISC-DHCP-SERVER ===${NC}\n"
    
    interface=$(select_interface "Выберите интерфейс для DHCP сервера:")
    [[ -z "$interface" ]] && return 1
    
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
    
    wait_for_enter
}

# Функция настройки dnsmasq
setup_dnsmasq() {
    echo -e "\n${GREEN}=== НАСТРОЙКА DNSMASQ ===${NC}\n"
    
    interface=$(select_interface "Выберите интерфейс для DNSMASQ:")
    [[ -z "$interface" ]] && return 1
    
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
    
    wait_for_enter
}

# Функция настройки DHCP через systemd-networkd
setup_systemd_networkd_dhcp() {
    echo -e "\n${GREEN}=== НАСТРОЙКА DHCP СЕРВЕРА (SYSTEMD-NETWORKD) ===${NC}\n"
    
    interface=$(select_interface "Выберите интерфейс для DHCP сервера:")
    [[ -z "$interface" ]] && return 1
    
    echo -e "\n${YELLOW}Выберите режим:${NC}"
    echo "1. Только DHCP сервер (раздача адресов клиентам)"
    echo "2. DHCP сервер + статический IP на интерфейсе"
    echo "3. DHCP клиент (получение адреса)"
    read -p "Выберите опцию [1-3]: " mode_choice
    
    mkdir -p $NETWORKD_DIR
    
    case $mode_choice in
        1)
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
    
    wait_for_enter
}

# Функция установки DHCP сервера
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
    
    wait_for_enter
}

# ==================== ФУНКЦИИ УПРАВЛЕНИЯ ИНТЕРФЕЙСАМИ ====================

# Функция проверки и исправления IP адреса
fix_ip_address() {
    echo -e "\n${GREEN}=== ПРОВЕРКА И ИСПРАВЛЕНИЕ IP АДРЕСА ===${NC}\n"

    interface=$(select_interface "Выберите интерфейс для настройки:")
    [[ -z "$interface" ]] && return 1

    echo -e "\n${YELLOW}Текущее состояние:${NC}"
    ip addr show $interface 2>/dev/null || echo "Интерфейс не найден"

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
            configure_ip_temp $interface "static"
            ;;
        2)
            configure_ip_permanent $interface "static"
            ;;
        3)
            configure_ip_temp $interface "dhcp"
            ;;
        4)
            configure_ip_permanent $interface "dhcp"
            ;;
        5)
            reset_interface_config $interface
            ;;
        6)
            test_interface_connectivity $interface
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    wait_for_enter
}

# Вспомогательная функция временной настройки IP
configure_ip_temp() {
    local interface=$1
    local mode=$2
    
    case $mode in
        static)
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
        dhcp)
            echo "Включаем DHCP временно..."
            dhclient -r $interface 2>/dev/null
            dhclient $interface 2>/dev/null &

            sleep 3
            echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
            ip addr show $interface
            echo -e "${YELLOW}Внимание: Эти настройки будут сброшены после перезагрузки!${NC}"
            ;;
    esac
}

# Вспомогательная функция постоянной настройки IP
configure_ip_permanent() {
    local interface=$1
    local mode=$2
    
    # Проверяем доступные методы конфигурации
    local has_netplan=false
    local has_systemd_networkd=false

    [[ -d "/etc/netplan" ]] && ls /etc/netplan/*.yaml 2>/dev/null >/dev/null && has_netplan=true
    systemctl is-active systemd-networkd >/dev/null 2>&1 && [[ -d "$NETWORKD_DIR" ]] && has_systemd_networkd=true

    if ! $has_netplan && ! $has_systemd_networkd; then
        echo "Не найдены методы конфигурации."
        return 1
    fi

    echo -e "\n${YELLOW}Выберите метод сохранения:${NC}"
    if $has_netplan && $has_systemd_networkd; then
        echo "1. Netplan (рекомендуется для Ubuntu)"
        echo "2. systemd-networkd"
        read -p "Выберите [1-2]: " method_choice
    elif $has_netplan; then
        echo "1. Netplan"
        method_choice=1
    else
        echo "2. systemd-networkd"
        method_choice=2
    fi

    case $mode in
        static)
            read -p "Введите IP адрес [192.168.10.1]: " static_ip
            static_ip=${static_ip:-"192.168.10.1"}
            read -p "Введите маску подсети [24]: " netmask
            netmask=${netmask:-"24"}
            
            case $method_choice in
                1)
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
                    netplan apply
                    echo -e "${GREEN}Настройки Netplan сохранены в $netplan_file${NC}"
                    ;;
                2)
                    network_file="$NETWORKD_DIR/10-$interface.network"
                    cat > $network_file << EOF
[Match]
Name=$interface

[Network]
Address=$static_ip/$netmask
EOF
                    systemctl restart systemd-networkd
                    echo -e "${GREEN}Настройки systemd-networkd сохранены в $network_file${NC}"
                    ;;
            esac
            ;;
        dhcp)
            case $method_choice in
                1)
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
                    netplan apply
                    echo -e "${GREEN}Настройки DHCP через Netplan сохранены${NC}"
                    ;;
                2)
                    network_file="$NETWORKD_DIR/10-$interface.network"
                    cat > $network_file << EOF
[Match]
Name=$interface

[Network]
DHCP=yes
EOF
                    systemctl restart systemd-networkd
                    echo -e "${GREEN}Настройки DHCP через systemd-networkd сохранены${NC}"
                    ;;
            esac
            ;;
    esac

    # Применяем временно для немедленного эффекта
    ip addr flush dev $interface 2>/dev/null
    [[ "$mode" == "static" ]] && ip addr add $static_ip/$netmask dev $interface 2>/dev/null
    ip link set $interface up 2>/dev/null

    echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
    ip addr show $interface
}

# Вспомогательная функция сброса настроек интерфейса
reset_interface_config() {
    local interface=$1
    
    echo "Сбрасываем настройки интерфейса..."

    # Временный сброс
    ip addr flush dev $interface 2>/dev/null
    ip link set $interface down 2>/dev/null
    sleep 1
    ip link set $interface up 2>/dev/null

    # Удаляем конфигурационные файлы
    echo "Удаляем конфигурационные файлы..."
    rm -f /etc/netplan/*-$interface-*.yaml 2>/dev/null
    rm -f /etc/netplan/*-$interface.yaml 2>/dev/null
    rm -f $NETWORKD_DIR/*-$interface.network 2>/dev/null
    rm -f $NETWORKD_DIR/*-$interface.network 2>/dev/null

    # Применяем изменения
    [[ -d "/etc/netplan" ]] && netplan apply 2>/dev/null
    [[ -d "$NETWORKD_DIR" ]] && systemctl restart systemd-networkd 2>/dev/null

    echo -e "\n${GREEN}Текущее состояние интерфейса:${NC}"
    ip addr show $interface
    echo -e "${GREEN}Все настройки интерфейса сброшены${NC}"
}

# Вспомогательная функция проверки соединения интерфейса
test_interface_connectivity() {
    local interface=$1
    
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
}

# Функция настройки статического IP
setup_static_ip() {
    echo -e "\n${GREEN}=== НАСТРОЙКА СТАТИЧЕСКОГО IP ===${NC}\n"
    
    interface=$(select_interface "Выберите интерфейс для статического IP:")
    [[ -z "$interface" ]] && return 1
    
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
    
    wait_for_enter
}

# ==================== ФУНКЦИИ УПРАВЛЕНИЯ СЛУЖБАМИ ====================

# Функция управления systemd-networkd
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
    
    wait_for_enter
}

# Функция просмотра конфигурации systemd-networkd
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
        [[ -f "$file" ]] && echo -e "\n=== $(basename "$file") ===" && cat "$file"
    done 2>/dev/null

    echo -e "\nТекущее состояние:"
    systemctl status systemd-networkd --no-pager -l | head -20

    wait_for_enter
}

# Функция перезапуска сетевых служб
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
    
    wait_for_enter
}

# Функция сброса сетевых настроек
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
    
    wait_for_enter
}

# ==================== ФУНКЦИИ БЕКАПА И ВОССТАНОВЛЕНИЯ ====================

# Функция резервного копирования
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
    
    wait_for_enter
}

# Функция восстановления из резервной копии
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
    
    wait_for_enter
}

# ==================== ФУНКЦИИ ДИАГНОСТИКИ И МОНИТОРИНГА ====================

# Функция показа логов DHCP сервера
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
    
    wait_for_enter
}

# Функция проверки клиентов DHCP
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
    
    wait_for_enter
}

# Функция мониторинга DHCP трафика
monitor_dhcp_traffic() {
    echo -e "\n${GREEN}=== МОНИТОРИНГ DHCP ТРАФИКА ===${NC}\n"

    if ! command -v tcpdump &> /dev/null; then
        echo "Установка tcpdump..."
        apt update && apt install -y tcpdump
    fi

    interface=$(select_interface "Выберите интерфейс для мониторинга:")
    [[ -z "$interface" ]] && return 1

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

    trap - SIGINT SIGTERM

    echo -e "\n${GREEN}Мониторинг завершен${NC}"
    wait_for_enter
}

# Функция показа текущей конфигурации сети
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
    
    wait_for_enter
}

# Функция тестирования соединения
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
    
    wait_for_enter
}

# ==================== ФУНКЦИИ БЕЗОПАСНОСТИ ====================

# Функция управления UFW
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
    read -p "Выберите опцию [1-9]: " ufw_option

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
            [[ -n "$port" ]] && ufw allow $port && echo -e "${GREEN}Порт $port разрешен${NC}"
            ;;
        4)
            read -p "Введите порт (например: 80, 22/tcp): " port
            [[ -n "$port" ]] && ufw deny $port && echo -e "${RED}Порт $port запрещен${NC}"
            ;;
        5)
            echo "Доступные службы:"
            ufw app list
            read -p "Введите имя службы: " service
            [[ -n "$service" ]] && ufw allow "$service" && echo -e "${GREEN}Служба $service разрешена${NC}"
            ;;
        6)
            read -p "Вы уверены, что хотите сбросить все правила? (y/N): " confirm
            [[ $confirm == "y" || $confirm == "Y" ]] && ufw --force reset && echo -e "${YELLOW}Все правила UFW сброшены${NC}"
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
        *)
            echo "Неверный выбор"
            ;;
    esac

    wait_for_enter
}

# Функция управления iptables
manage_iptables() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ IPTABLES ===${NC}\n"

    # Проверяем установлен ли iptables
    if ! command -v iptables &> /dev/null; then
        echo -e "${YELLOW}iptables не установлен. Устанавливаем...${NC}"
        apt update && apt install -y iptables iptables-persistent
        if [ $? -ne 0 ]; then
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
    read -p "Выберите опцию [1-8]: " iptables_option

    case $iptables_option in
        1)
            echo -e "\n${YELLOW}Все правила iptables:${NC}"
            iptables -L -v -n --line-numbers
            ;;
        2)
            read -p "Введите путь для сохранения [$IPTABLES_BACKUP]: " backup_file
            backup_file=${backup_file:-$IPTABLES_BACKUP}

            iptables-save > $backup_file
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
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4
            ip6tables-save > /etc/iptables/rules.v6
            echo -e "${GREEN}Правила сохранены в /etc/iptables/${NC}"
            ;;
        6)
            echo "Добавляем правила для DHCP сервера..."
            iptables -A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
            iptables -A OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
            echo -e "${GREEN}Правила для DHCP добавлены${NC}"
            ;;
        7)
            manage_iptables_nat
            ;;
        8)
            echo "Настраиваем базовые правила безопасности..."
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A OUTPUT -o lo -j ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -p tcp --dport 22 -j ACCEPT
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            iptables -A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
            echo -e "${GREEN}Базовые правила безопасности настроены${NC}"
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    wait_for_enter
}

# Вспомогательная функция настройки NAT в iptables
manage_iptables_nat() {
    internal_if=$(select_interface "Выберите внутренний интерфейс:")
    [[ -z "$internal_if" ]] && return 1

    external_if=$(select_interface "Выберите внешний интерфейс:")
    [[ -z "$external_if" ]] && return 1

    echo "Добавляем правила NAT..."
    sysctl -w net.ipv4.ip_forward=1
    iptables -t nat -A POSTROUTING -o $external_if -j MASQUERADE
    iptables -A FORWARD -i $internal_if -o $external_if -j ACCEPT
    iptables -A FORWARD -i $external_if -o $internal_if -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -i $internal_if -j ACCEPT

    echo -e "${GREEN}Правила NAT настроены для интерфейсов:${NC}"
    echo "Внутренний: $internal_if"
    echo "Внешний: $external_if"
}

# ==================== ФУНКЦИИ МАРШРУТИЗАЦИИ ====================

# Функция управления IP Forwarding
manage_ip_forwarding() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ IP FORWARDING ===${NC}\n"

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
    echo "4. Показать правила iptables для forward"
    read -p "Выберите опцию [1-4]: " forward_option

    case $forward_option in
        1)
            sysctl -w net.ipv4.ip_forward=1
            echo -e "${GREEN}IP Forwarding включен (временно)${NC}"
            ;;
        2)
            sysctl -w net.ipv4.ip_forward=0
            echo -e "${YELLOW}IP Forwarding выключен${NC}"
            ;;
        3)
            sysctl -w net.ipv4.ip_forward=1
            if grep -q "net.ipv4.ip_forward" /etc/sysctl.conf; then
                sed -i 's/^#*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
            else
                echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
            fi
            sysctl -p
            echo -e "${GREEN}IP Forwarding включен и сохранен в /etc/sysctl.conf${NC}"
            ;;
        4)
            echo -e "\n${YELLOW}Правила FORWARD (таблица filter):${NC}"
            iptables -L FORWARD -v -n
            echo -e "\n${YELLOW}Текущее состояние IP Forwarding:${NC}"
            sysctl net.ipv4.ip_forward
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    wait_for_enter
}

# Функция управления маршрутизацией
manage_routing() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ МАРШРУТИЗАЦИЕЙ ===${NC}\n"

    echo -e "${YELLOW}Текущая таблица маршрутизации:${NC}"
    ip -c route show
    echo ""

    echo -e "${YELLOW}Опции управления маршрутизацией:${NC}"
    echo "1. Добавить маршрут по умолчанию (шлюз)"
    echo "2. Добавить статический маршрут к сети"
    echo "3. Удалить маршрут"
    echo "4. Показать подробную таблицу маршрутизации"
    echo "5. Настроить маршрут через systemd-networkd"
    read -p "Выберите опцию [1-5]: " routing_option

    case $routing_option in
        1)
            manage_add_default_route
            ;;
        2)
            manage_add_static_route
            ;;
        3)
            manage_delete_route
            ;;
        4)
            echo -e "\n${YELLOW}Подробная таблица маршрутизации:${NC}"
            ip route show table all 2>/dev/null || ip route show
            ;;
        5)
            manage_systemd_networkd_route
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    echo -e "\n${YELLOW}Текущая таблица маршрутизации:${NC}"
    ip -c route show

    wait_for_enter
}

# Вспомогательные функции для управления маршрутизацией
manage_add_default_route() {
    interface=$(select_interface "Выберите интерфейс для маршрута по умолчанию:")
    [[ -z "$interface" ]] && return 1

    current_ip=$(ip -4 addr show $interface 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
    if [ -n "$current_ip" ]; then
        gateway_hint=$(echo $current_ip | sed 's/\.[0-9]*$/.1/')
        echo "Текущий IP на $interface: $current_ip"
        echo "Предполагаемый шлюз: $gateway_hint"
    fi

    read -p "Введите IP адрес шлюза: " gateway_ip
    [[ -z "$gateway_ip" ]] && echo -e "${RED}Шлюз не указан!${NC}" && return 1

    existing_default=$(ip route show default 2>/dev/null)
    if [ -n "$existing_default" ]; then
        echo -e "${YELLOW}Существующий маршрут по умолчанию:${NC}"
        echo "$existing_default"
        read -p "Заменить его? (y/N): " replace_conf
        [[ "$replace_conf" =~ ^[Yy]$ ]] && ip route del default 2>/dev/null
    fi

    ip route add default via $gateway_ip dev $interface
    ip route show default | grep -q "$interface" && echo -e "${GREEN}Маршрут по умолчанию добавлен успешно!${NC}" || echo -e "${RED}Ошибка добавления маршрута!${NC}"
}

manage_add_static_route() {
    read -p "Введите сеть назначения (например: 192.168.2.0/24): " dest_network
    [[ -z "$dest_network" ]] && echo -e "${RED}Сеть не указана!${NC}" && return 1

    echo "Выберите способ указания шлюза:"
    echo "1. Через IP адрес шлюза"
    echo "2. Через интерфейс (для подключенных сетей)"
    read -p "Выберите [1-2]: " gw_method

    case $gw_method in
        1)
            read -p "Введите IP адрес шлюза: " gateway_ip
            [[ -z "$gateway_ip" ]] && echo -e "${RED}Шлюз не указан!${NC}" && return 1
            ip route add $dest_network via $gateway_ip
            ip route show | grep -q "$dest_network" && echo -e "${GREEN}Маршрут добавлен успешно!${NC}" || echo -e "${RED}Ошибка добавления маршрута!${NC}"
            ;;
        2)
            interface=$(select_interface "Выберите интерфейс для маршрута:")
            [[ -z "$interface" ]] && return 1
            ip route add $dest_network dev $interface
            ip route show | grep -q "$dest_network.*dev $interface" && echo -e "${GREEN}Маршрут добавлен успешно!${NC}" || echo -e "${RED}Ошибка добавления маршрута!${NC}"
            ;;
    esac
}

manage_delete_route() {
    echo "Текущие маршруты:"
    ip route show | grep -v "^default" | cat -n

    read -p "Введите номер маршрута для удаления: " route_num
    route_to_delete=$(ip route show | grep -v "^default" | sed -n "${route_num}p")
    [[ -z "$route_to_delete" ]] && echo -e "${RED}Маршрут не найден!${NC}" && return 1

    echo "Удаляем маршрут: $route_to_delete"
    read -p "Вы уверены? (y/N): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] && ip route del $route_to_delete && echo -e "${GREEN}Маршрут удален!${NC}"
}

manage_systemd_networkd_route() {
    [[ ! -d "$NETWORKD_DIR" ]] && echo -e "${RED}Директория systemd-networkd не найдена!${NC}" && return 1

    interface=$(select_interface "Выберите интерфейс для настройки:")
    [[ -z "$interface" ]] && return 1

    network_file="$NETWORKD_DIR/10-$interface.network"
    if [ -f "$network_file" ]; then
        echo -e "${YELLOW}Текущий конфиг $network_file:${NC}"
        cat "$network_file"
        read -p "Перезаписать? (y/N): " overwrite
        [[ ! "$overwrite" =~ ^[Yy]$ ]] && return 1
    fi

    read -p "Введите IP адрес шлюза для default маршрута: " sysd_gateway

    # Создаем конфиг
    mkdir -p $NETWORKD_DIR
    cat > "$network_file" << EOF
[Match]
Name=$interface

[Network]
$( [ -n "$sysd_gateway" ] && echo "Gateway=$sysd_gateway" )
EOF

    echo -e "\n${GREEN}Конфиг создан:${NC}"
    cat "$network_file"

    echo -e "\nПрименяем изменения..."
    systemctl restart systemd-networkd
}

# ==================== ФУНКЦИИ УПРАВЛЕНИЯ ПЕРЕИМЕНОВАНИЕМ ИНТЕРФЕЙСОВ ====================

# Функция управления переименованием сетевых интерфейсов
manage_interface_renaming() {
    echo -e "\n${GREEN}=== УПРАВЛЕНИЕ ПЕРЕИМЕНОВАНИЕМ СЕТЕВЫХ ИНТЕРФЕЙСОВ ===${NC}\n"

    echo -e "${YELLOW}Текущие сетевые интерфейсы:${NC}"
    ip -o link show | awk -F': ' '{print $2}' | grep -v lo
    echo ""

    echo -e "${YELLOW}Опции управления:${NC}"
    echo "1. Отключить переименование интерфейсов (predictable)"
    echo "2. Включить переименование интерфейсов (predictable)"
    echo "3. Использовать старые имена (ethX)"
    echo "4. Восстановить настройки по умолчанию"
    read -p "Выберите опцию [1-4]: " rename_option

    case $rename_option in
        1)
            manage_interface_renaming_option "net.ifnames=0 biosdevname=0"
            ;;
        2)
            manage_interface_renaming_option ""
            ;;
        3)
            manage_interface_renaming_option "net.ifnames=0 biosdevname=0"
            echo -e "\n${GREEN}Настройка завершена!${NC}"
            echo "После перезагрузки интерфейсы будут называться eth0, eth1 и т.д."
            ;;
        4)
            echo -e "\n${YELLOW}Восстановление настроек по умолчанию...${NC}"
            sed -i 's/net.ifnames=0//g' /etc/default/grub
            sed -i 's/biosdevname=0//g' /etc/default/grub
            sed -i 's/  */ /g' /etc/default/grub
            sed -i 's/^ //' /etc/default/grub
            sed -i 's/ $//' /etc/default/grub
            update-grub 2>/dev/null || grub-mkconfig -o /boot/grub/grub.cfg
            echo -e "\n${GREEN}Настройки восстановлены!${NC}"
            echo "Перезагрузите систему для применения изменений."
            ;;
        *)
            echo "Неверный выбор"
            ;;
    esac

    echo -e "\n${YELLOW}Текущие параметры загрузки:${NC}"
    cat /proc/cmdline | grep -o "net.ifnames[^ ]*\|biosdevname[^ ]*" || echo "Параметры не установлены"

    wait_for_enter
}

# Вспомогательная функция для изменения параметров GRUB
manage_interface_renaming_option() {
    local params=$1

    [[ ! -f /etc/default/grub ]] && echo -e "${RED}Файл /etc/default/grub не найден!${NC}" && return 1

    # Создаем резервную копию
    cp /etc/default/grub "/etc/default/grub.backup.$(date +%Y%m%d_%H%M%S)"

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
        command -v update-grub >/dev/null && update-grub || command -v grub-mkconfig >/dev/null && grub-mkconfig -o /boot/grub/grub.cfg

        echo -e "\n${GREEN}Конфигурация обновлена!${NC}"
        echo -e "${YELLOW}Для применения изменений необходима перезагрузка.${NC}"

    else
        echo -e "${RED}Ошибка: Не найдена строка GRUB_CMDLINE_LINUX${NC}"
    fi
}

# ==================== ОСНОВНОЙ ЦИКЛ ====================

# Основной цикл
main() {
    check_root

    while true; do
        show_menu
        read choice

        case $choice in
            1) show_diagnostic_submenu ;;
            2) show_dhcp_setup_submenu ;;
            3) show_interface_management_submenu ;;
            4) show_services_management_submenu ;;
            5) show_backup_restore_submenu ;;
            6) show_security_submenu ;;
            7) show_routing_submenu ;;
            8)
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
