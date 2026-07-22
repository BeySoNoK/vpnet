#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${GREEN}=== Установка EasyTier Secure Mode (root) ===${NC}"

WORKDIR="/root/vpn"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Установка EasyTier, если нет
if ! command -v easytier-core &> /dev/null; then
    echo -e "${YELLOW}Установка EasyTier...${NC}"
    apt update && apt install -y wget curl unzip openssl screen
    curl -fsSL "https://github.com/EasyTier/EasyTier/blob/main/script/install.sh?raw=true" | bash -s install
fi

# Остановка и отключение системного сервиса (если есть)
if systemctl list-units --all | grep -q easytier@default; then
    echo -e "${YELLOW}Отключаем системный сервис easytier@default...${NC}"
    systemctl stop easytier@default.service || true
    systemctl disable easytier@default.service || true
    systemctl mask easytier@default.service || true
fi

# Генерация ключа администратора
ADMIN_KEY_FILE="admin.key"
if [[ ! -f "$ADMIN_KEY_FILE" ]]; then
    ADMIN_KEY=$(openssl rand -base64 32)
    echo "$ADMIN_KEY" > "$ADMIN_KEY_FILE"
    chmod 600 "$ADMIN_KEY_FILE"
    echo -e "${GREEN}Новый ключ сохранён в admin.key${NC}"
    echo -e "${RED}Сохраните этот ключ: $ADMIN_KEY${NC}"
else
    ADMIN_KEY=$(cat "$ADMIN_KEY_FILE")
    echo -e "${GREEN}Ключ загружен из admin.key${NC}"
fi

# Создание скрипта администратора
cat > start-admin.sh << EOF
#!/bin/bash
ADMIN_KEY=\$(cat $WORKDIR/admin.key)
easytier-core \\
  --network-name "BeySoN-VPN" \\
  --network-secret "Asdf1234" \\
  --secure-mode \\
  --local-private-key "\$ADMIN_KEY" \\
  --dhcp \\
  -e tcp://qwe.p8.ink:11010,tcp://37.221.197.17:11010 \\
  --credential-file $WORKDIR/credentials.json
EOF
chmod +x start-admin.sh

# Скрипт генерации приглашений
cat > generate-invite.sh << 'EOF'
#!/bin/bash
TTL=${1:-30d}
OUTPUT=$(easytier-cli credential generate --ttl "$TTL")
SECRET=$(echo "$OUTPUT" | grep -o '"secret": *"[^"]*"' | cut -d'"' -f4)
echo "$SECRET" > guest.cred
chmod 600 guest.cred
echo "Ключ приглашения (отправьте гостю):"
echo "$SECRET"
EOF
chmod +x generate-invite.sh

# Скрипт для гостя
cat > start-guest.sh << 'EOF'
#!/bin/bash
if [[ $# -ge 1 ]]; then
    CRED="$1"
else
    if [[ -f guest.cred ]]; then
        CRED=$(cat guest.cred)
    else
        echo "Ошибка: нет ключа. Используйте: $0 <ключ>"
        exit 1
    fi
fi
easytier-core --network-name "BeySoN-VPN" --credential "$CRED" --dhcp -e tcp://qwe.p8.ink:11010,tcp://37.221.197.17:11010
EOF
chmod +x start-guest.sh

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Установка завершена!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Запустите администратор в screen:"
echo "   screen -S vpn"
echo "   cd /root/vpn && ./start-admin.sh"
echo "   (нажмите Ctrl+A, D для выхода)"
echo ""
echo "2. Сгенерируйте приглашение:"
echo "   cd /root/vpn && ./generate-invite.sh 30d"
echo ""
echo "3. Гость запускает: ./start-guest.sh <ключ>"
