#!/bin/bash

# Продвинутый скрипт настройки маршрутизатора с фиксацией интерфейсов
# Выбор интерфейсов цифрами + отключение переименования через параметры ядра

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции вывода
print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }
print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_choice() { echo -e "${PURPLE}$1${NC}"; }

# Функция для выбора опции
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    
    while true; do
        clear
        echo -e "${CYAN}$prompt${NC}"
        echo ""
        
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "${GREEN}→ $((i+1)). ${options[i]}${NC}"
            else
                echo "  $((i+1)). ${options[i]}"
            fi
        done
        
        echo ""
        echo "Используйте: ↑/↓ для навигации, Enter для выбора"
        
        read -rsn1 key
        case $key in
            $'\x1b')  # Escape sequence
                read -rsn2 key
                case $key in
                    '[A') # Up arrow
                        if [ $selected -gt 0 ]; then
                            ((selected--))
                        fi
                        ;;
                    '[B') # Down arrow
                        if [ $((selected+1)) -lt ${#options[@]} ]; then
                            ((selected++))
                        fi
                        ;;
                esac
                ;;
            '') # Enter key
                echo $selected
                return
                ;;
        esac
    done
}

# Функция выбора интерфейса цифрами
select_interface() {
    local prompt="$1"
    local interfaces=()
    
    print_step "$prompt"
    
    # Получаем список интерфейсов
    while IFS= read -r line; do
        iface=$(echo "$line" | awk '{print $1}' | sed 's/@.*//')
        state=$(echo "$line" | awk '{print $2}')
        mac=$(echo "$line" | awk '{print $3}')
        
        # Пропускаем loopback и виртуальные интерфейсы
        if [[ "$iface" == "lo" ]] || [[ "$state" == "DOWN" ]] || [[ -z "$mac" ]]; then
            continue
        fi
        
        # Определяем тип интерфейса
        if [[ "$iface" =~ ^(wwan|usb|cdc) ]] || [[ "$mac" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
            type="(вероятно USB модем)"
        elif [[ "$iface" =~ ^(eth|en|eno|ens|enp) ]]; then
            type="(вероятно Ethernet)"
        else
            type="(неизвестно)"
        fi
        
        interfaces+=("$iface - $mac $type")
    done < <(ip -o link show | grep -v "loopback")
    
    if [ ${#interfaces[@]} -eq 0 ]; then
        print_error "Не найдено активных сетевых интерфейсов!"
        exit 1
    fi
    
    # Добавляем опцию ручного ввода
    interfaces+=("Ввести имя интерфейса вручную")
    
    echo ""
    echo "Доступные интерфейсы:"
    for i in "${!interfaces[@]}"; do
        echo "  $((i+1)). ${interfaces[i]}"
    done
    
    while true; do
        echo ""
        read -p "Выберите номер интерфейса [1-${#interfaces[@]}]: " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#interfaces[@]} ]; then
            selected_index=$((choice-1))
            selected_option="${interfaces[selected_index]}"
            
            if [ "$selected_option" == "Ввести имя интерфейса вручную" ]; then
                read -p "Введите имя интерфейса: " manual_iface
                if ip link show "$manual_iface" >/dev/null 2>&1; then
                    echo "$manual_iface"
                    return
                else
                    print_error "Интерфейс $manual_iface не найден!"
                    continue
                fi
            fi
            
            # Извлекаем имя интерфейса из строки
            selected_iface=$(echo "$selected_option" | awk '{print $1}')
            echo "$selected_iface"
            return
        else
            print_error "Неверный выбор. Попробуйте снова."
        fi
    done
}

# Функция отключения переименования интерфейсов через параметры ядра
disable_interface_renaming() {
    print_step "Отключаем автоматическое переименование интерфейсов"
    
    local method=$1
    
    case $method in
        "kernel")  # Через параметры ядра
            print_info "Метод: параметры ядра (самый надежный)"
            
            # 1. Добавляем параметры в GRUB
            if [ -f /etc/default/grub ]; then
                print_info "Обновляем параметры GRUB..."
                
                # Удаляем старые параметры если есть
                sed -i 's/GRUB_CMDLINE_LINUX=".*net.ifnames=.*"/GRUB_CMDLINE_LINUX=""/g' /etc/default/grub
                sed -i 's/GRUB_CMDLINE_LINUX=".*biosdevname=.*"/GRUB_CMDLINE_LINUX=""/g' /etc/default/grub
                
                # Получаем текущую строку
                current_cmdline=$(grep '^GRUB_CMDLINE_LINUX=' /etc/default/grub | cut -d'"' -f2)
                
                # Добавляем новые параметры
                new_params="net.ifnames=0 biosdevname=0"
                if [[ -z "$current_cmdline" ]]; then
                    sed -i "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$new_params\"/" /etc/default/grub
                else
                    # Проверяем, нет ли уже этих параметров
                    if [[ ! "$current_cmdline" =~ net.ifnames= ]]; then
                        current_cmdline="$current_cmdline net.ifnames=0"
                    fi
                    if [[ ! "$current_cmdline" =~ biosdevname= ]]; then
                        current_cmdline="$current_cmdline biosdevname=0"
                    fi
                    sed -i "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$current_cmdline\"/" /etc/default/grub
                fi
                
                print_info "GRUB обновлен с параметрами: $new_params"
            fi
            
            # 2. Создаем правило для systemd
            print_info "Создаем правило для systemd..."
            cat > /etc/systemd/network/99-disable-renaming.link << 'EOF'
[Match]
OriginalName=*

[Link]
NamePolicy=keep
MACAddressPolicy=persistent
EOF
            
            # 3. Отключаем systemd-networkd-wait-online если мешает
            systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
            
            ;;
            
        "udev")  # Через правила udev
            print_info "Метод: правила udev"
            
            # Создаем правила udev
            cat > /etc/udev/rules.d/70-persistent-net.rules << 'EOF'
# Правила для фиксации имен сетевых интерфейсов
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{type}=="1", KERNEL=="eth*", NAME="eth%n"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan%n"
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{type}=="1", KERNEL=="wwan*", NAME="wwan%n"
EOF
            
            # Обновляем правила
            udevadm control --reload-rules
            udevadm trigger --attr-match=subsystem=net
            
            ;;
            
        "both")  # Оба метода
            disable_interface_renaming "kernel"
            disable_interface_renaming "udev"
            ;;
    esac
    
    # 4. Отключаем predictable network interface names
    ln -sf /dev/null /etc/systemd/network/99-default.link 2>/dev/null || true
    
    print_info "Автоматическое переименование отключено методом: $method"
}

# Функция настройки фиксированных имен для конкретных интерфейсов
setup_fixed_names() {
    local usb_iface=$1
    local eth_iface=$2
    local usb_name=$3
    local eth_name=$4
    
    print_step "Настраиваем фиксированные имена для интерфейсов"
    
    # Получаем MAC-адреса
    usb_mac=$(ip link show "$usb_iface" 2>/dev/null | grep -oP 'link/ether \K[0-9a-f:]+' || echo "")
    eth_mac=$(ip link show "$eth_iface" 2>/dev/null | grep -oP 'link/ether \K[0-9a-f:]+' || echo "")
    
    if [ -z "$usb_mac" ] || [ -z "$eth_mac" ]; then
        print_warn "Не удалось определить MAC-адреса. Используем текущие имена."
        usb_name="$usb_iface"
        eth_name="$eth_iface"
    else
        print_info "MAC USB ($usb_iface): $usb_mac → $usb_name"
        print_info "MAC Ethernet ($eth_iface): $eth_mac → $eth_name"
        
        # Создаем правило udev для фиксации по MAC
        cat > /etc/udev/rules.d/71-custom-net.rules << EOF
# Фиксированные имена для наших интерфейсов
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$usb_mac", NAME="$usb_name"
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="$eth_mac", NAME="$eth_name"
EOF
        
        # Обновляем правила
        udevadm control --reload-rules
    fi
}

# Функция проверки доступности интерфейса
check_interface() {
    local iface=$1
    local purpose=$2
    
    if ip link show "$iface" >/dev/null 2>&1; then
        local state=$(ip link show "$iface" | grep -oP 'state \K\w+')
        local mac=$(ip link show "$iface" | grep -oP 'link/ether \K[0-9a-f:]+' || echo "не определен")
        print_info "$purpose: $iface (состояние: $state, MAC: $mac)"
        return 0
    else
        print_error "$purpose: интерфейс $iface не найден!"
        return 1
    fi
}

# Основная программа
main() {
    print_header "ПРОДВИНУТАЯ НАСТРОЙКА МАРШРУТИЗАТОРА"
    
    # Проверка прав
    if [ "$EUID" -ne 0 ]; then 
        print_error "Требуются права root. Запустите: sudo $0"
        exit 1
    fi
    
    # Шаг 1: Выбор метода отключения переименования
    print_header "1. НАСТРОЙКА ФИКСАЦИИ ИМЕН ИНТЕРФЕЙСОВ"
    
    echo ""
    echo "Выберите метод отключения автоматического переименования:"
    options=(
        "Параметры ядра (рекомендуется) - net.ifnames=0 biosdevname=0"
        "Правила udev"
        "Оба метода (наиболее надежно)"
        "Пропустить (оставить как есть)"
    )
    
    choice=$(select_option "Метод фиксации имен интерфейсов:" "${options[@]}")
    
    case $choice in
        0) disable_interface_renaming "kernel" ;;
        1) disable_interface_renaming "udev" ;;
        2) disable_interface_renaming "both" ;;
        3) print_info "Пропускаем настройку фиксации имен" ;;
    esac
    
    # Шаг 2: Выбор интерфейсов
    print_header "2. ВЫБОР СЕТЕВЫХ ИНТЕРФЕЙСОВ"
    
    # Выбор USB модема
    usb_interface=$(select_interface "Выберите интерфейс USB-модема (WAN):")
    check_interface "$usb_interface" "USB модем (WAN)"
    
    echo ""
    
    # Выбор Ethernet порта
    eth_interface=$(select_interface "Выберите интерфейс Ethernet порта (LAN):")
    check_interface "$eth_interface" "Ethernet порт (LAN)"
    
    # Проверка что интерфейсы разные
    if [ "$usb_interface" == "$eth_interface" ]; then
        print_error "Выбран один и тот же интерфейс для WAN и LAN!"
        exit 1
    fi
    
    # Шаг 3: Настройка имен интерфейсов
    print_header "3. НАСТРОЙКА ФИКСИРОВАННЫХ ИМЕН"
    
    read -p "Имя для USB модема [${usb_interface}]: " usb_name
    usb_name=${usb_name:-$usb_interface}
    
    read -p "Имя для Ethernet порта [${eth_interface}]: " eth_name
    eth_name=${eth_name:-$eth_interface}
    
    # Настраиваем фиксированные имена
    setup_fixed_names "$usb_interface" "$eth_interface" "$usb_name" "$eth_name"
    
    # Шаг 4: Сетевые настройки
    print_header "4. СЕТЕВЫЕ НАСТРОЙКИ"
    
    # Подсеть
    read -p "Подсеть LAN [192.168.10.0/24]: " subnet
    subnet=${subnet:-"192.168.10.0/24"}
    
    # Извлекаем IP шлюза из подсети
    gateway_ip=$(echo "$subnet" | cut -d'/' -f1 | awk -F'.' '{print $1"."$2"."$3".1"}')
    
    # Диапазон DHCP
    read -p "Диапазон DHCP [192.168.10.100,192.168.10.200]: " dhcp_range
    dhcp_range=${dhcp_range:-"192.168.10.100,192.168.10.200"}
    
    # DNS серверы
    read -p "DNS серверы через запятую [8.8.8.8,8.8.4.4]: " dns_servers
    dns_servers=${dns_servers:-"8.8.8.8,8.8.4.4"}
    
    # Шаг 5: Подтверждение
    print_header "5. ПОДТВЕРЖДЕНИЕ НАСТРОЕК"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════"
    echo "                         СВОДКА НАСТРОЕК"
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📶 ИНТЕРФЕЙСЫ:"
    echo "   USB модем (WAN):    $usb_interface → $usb_name"
    echo "   Ethernet порт (LAN): $eth_interface → $eth_name"
    echo ""
    echo "🌐 СЕТЕВЫЕ НАСТРОЙКИ:"
    echo "   Подсеть LAN:        $subnet"
    echo "   IP шлюза:           $gateway_ip"
    echo "   Диапазон DHCP:      $dhcp_range"
    echo "   DNS серверы:        $dns_servers"
    echo ""
    echo "🔧 ДОПОЛНИТЕЛЬНО:"
    echo "   Фиксация имен:      $(if [ $choice -ne 3 ]; then echo "Да"; else echo "Нет"; fi)"
    echo "════════════════════════════════════════════════════════════════════════"
    echo ""
    
    read -p "Продолжить настройку? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Настройка отменена."
        exit 0
    fi
    
    # Шаг 6: Установка пакетов
    print_header "6. УСТАНОВКА ПАКЕТОВ"
    
    apt update
    apt install -y iptables-persistent netfilter-persistent isc-dhcp-server
    
    # Шаг 7: Настройка Netplan
    print_header "7. НАСТРОЙКА NETPLAN"
    
    cat > /etc/netplan/01-router.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $usb_name:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 100
      nameservers:
        addresses: [$(echo $dns_servers | sed 's/,/, /g')]
      optional: true
      
    $eth_name:
      addresses:
        - $gateway_ip/$(echo $subnet | cut -d'/' -f2)
      dhcp4: no
      dhcp6: no
EOF
    
    netplan apply
    
    # Шаг 8: Настройка DHCP
    print_header "8. НАСТРОЙКА DHCP СЕРВЕРА"
    
    systemctl stop isc-dhcp-server
    
    cat > /etc/dhcp/dhcpd.conf << EOF
authoritative;
default-lease-time 600;
max-lease-time 7200;

subnet $(echo $subnet | cut -d'/' -f1) netmask $(ipcalc -m $subnet 2>/dev/null | cut -d'=' -f2 || echo "255.255.255.0") {
  range $(echo $dhcp_range | cut -d',' -f1) $(echo $dhcp_range | cut -d',' -f2);
  option routers $gateway_ip;
  option domain-name-servers $(echo $dns_servers | sed 's/,/, /g');
  option domain-name "local";
  option broadcast-address $(echo $subnet | cut -d'/' -f1 | awk -F'.' '{print $1"."$2"."$3".255"}');
}
EOF
    
    echo "INTERFACESv4=\"$eth_name\"" > /etc/default/isc-dhcp-server
    
    systemctl start isc-dhcp-server
    systemctl enable isc-dhcp-server
    
    # Шаг 9: Настройка маршрутизации
    print_header "9. НАСТРОЙКА МАРШРУТИЗАЦИИ И NAT"
    
    # Включаем IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    
    # Настраиваем iptables
    iptables -F
    iptables -t nat -F
    iptables -X
    iptables -t nat -X
    
    # Правила NAT
    iptables -t nat -A POSTROUTING -o $usb_name -j MASQUERADE
    iptables -A FORWARD -i $eth_name -o $usb_name -j ACCEPT
    iptables -A FORWARD -i $usb_name -o $eth_name -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Базовые правила
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -i $eth_name -j ACCEPT
    iptables -A OUTPUT -o $eth_name -j ACCEPT
    iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
    
    # Сохраняем правила
    iptables-save > /etc/iptables/rules.v4
    
    # Шаг 10: Создание утилит
    print_header "10. СОЗДАНИЕ УТИЛИТ УПРАВЛЕНИЯ"
    
    # Скрипт проверки состояния
    cat > /usr/local/bin/router-status << EOF
#!/bin/bash
echo "=== СТАТУС МАРШРУТИЗАТОРА ==="
echo ""
echo "Интерфейсы:"
echo "  WAN ($usb_name): \$(ip -4 addr show $usb_name 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo 'нет IP')"
echo "  LAN ($eth_name): \$(ip -4 addr show $eth_name 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo 'нет IP')"
echo ""
echo "DHCP клиенты:"
grep "DHCPACK" /var/log/syslog | tail -5 | awk '{print \$1" "\$2" "\$3" - "\$8" "\$9}' || echo "  нет данных"
echo ""
echo "Проверка интернета:"
ping -c 2 -W 1 8.8.8.8 2>&1 | grep -E "(packets|time)" || echo "  нет соединения"
EOF
    
    chmod +x /usr/local/bin/router-status
    
    # Скрипт обновления GRUB
    if [ $choice -ne 3 ]; then
        cat > /usr/local/bin/update-grub-now << 'EOF'
#!/bin/bash
echo "Обновление конфигурации GRUB..."
update-grub
echo "Готово! Перезагрузите систему для применения изменений."
EOF
        chmod +x /usr/local/bin/update-grub-now
    fi
    
    # Шаг 11: Финальные действия
    print_header "11. ЗАВЕРШЕНИЕ НАСТРОЙКИ"
    
    # Сохранение настроек
    cat > /root/router-config-$(date +%Y%m%d-%H%M%S).txt << EOF
Настройки маршрутизатора:
Дата: $(date)

Интерфейсы:
  USB модем (WAN): $usb_interface → $usb_name
  Ethernet (LAN): $eth_interface → $eth_name

Сеть:
  Подсеть: $subnet
  Шлюз: $gateway_ip
  DHCP: $dhcp_range
  DNS: $dns_servers

Параметры ядра: $(if [ $choice -ne 3 ]; then echo "net.ifnames=0 biosdevname=0"; else echo "не изменялись"; fi)

Для применения параметров ядра выполните:
  update-grub
  reboot
EOF
    
    print_info "Настройка завершена!"
    echo ""
    echo "══════════════════════════════════════════════════════════════"
    echo "ДЕЙСТВИЯ ПОСЛЕ НАСТРОЙКИ:"
    echo ""
    
    if [ $choice -ne 3 ]; then
        echo "1. ОБНОВИТЬ GRUB И ПЕРЕЗАГРУЗИТЬСЯ:"
        echo "   sudo update-grub"
        echo "   sudo reboot"
        echo ""
    fi
    
    echo "2. ПРОВЕРИТЬ РАБОТУ:"
    echo "   sudo router-status"
    echo "   ping 8.8.8.8"
    echo ""
    echo "3. ПОДКЛЮЧИТЬ КЛИЕНТОВ:"
    echo "   Подключите ПК к порту $eth_name"
    echo "   Убедитесь что получает IP из диапазона $dhcp_range"
    echo ""
    echo "Настройки сохранены в: /root/router-config-*.txt"
    echo "══════════════════════════════════════════════════════════════"
}

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Использование: $0 [опции]"
            echo ""
            echo "Опции:"
            echo "  -h, --help     Показать эту справку"
            echo "  -a, --auto     Автоматический режим (использовать обнаруженные интерфейсы)"
            echo "  --no-fixnames  Не отключать автоматическое переименование"
            echo ""
            echo "Примеры:"
            echo "  sudo $0           # Интерактивный режим"
            echo "  sudo $0 --auto    # Автоматический режим"
            exit 0
            ;;
        --auto|-a)
            AUTO_MODE=1
            shift
            ;;
        --no-fixnames)
            NO_FIXNAMES=1
            shift
            ;;
        *)
            print_error "Неизвестный параметр: $1"
            exit 1
            ;;
    esac
done

# Запуск основной программы
main