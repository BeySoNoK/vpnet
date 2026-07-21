#!/bin/bash
# ================================================================
# EasyTier Secure Mode — установка для одного терминала
# Все файлы будут в /home/beyson/vpn
# ================================================================

set -e

# --- Цвета ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  EasyTier Secure Mode — Установка${NC}"
echo -e "${GREEN}  Все файлы в /home/beyson/vpn${NC}"
echo -e "${GREEN}==============================================${NC}"

# --- 1. Создаём рабочую папку и переходим в неё ---
WORKDIR="/home/beyson/vpn"
echo -e "${YELLOW}[1/5] Создание рабочей директории $WORKDIR...${NC}"
sudo mkdir -p "$WORKDIR"
sudo chown -R "$USER":"$USER" "$WORKDIR"  # делаем владельцем текущего пользователя
cd "$WORKDIR"
echo -e "${GREEN}✓ Перешли в $WORKDIR${NC}"

# --- 2. Проверка / установка EasyTier ---
echo -e "${YELLOW}[2/5] Проверка EasyTier...${NC}"
if ! command -v easytier-core &> /dev/null; then
    echo -e "${YELLOW}EasyTier не найден. Устанавливаем...${NC}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y wget curl unzip openssl screen
    curl -fsSL "https://github.com/EasyTier/EasyTier/blob/main/script/install.sh?raw=true" | sudo bash -s install
    echo -e "${GREEN}✓ EasyTier установлен${NC}"
else
    echo -e "${GREEN}✓ EasyTier уже установлен ($(easytier-core --version))${NC}"
fi

# --- 3. Генерация / чтение личного ключа администратора ---
echo -e "${YELLOW}[3/5] Личный ключ администратора...${NC}"
ADMIN_KEY_FILE="admin.key"
if [[ -f "$ADMIN_KEY_FILE" ]]; then
    ADMIN_KEY=$(cat "$ADMIN_KEY_FILE")
    echo -e "${GREEN}✓ Ключ загружен из $ADMIN_KEY_FILE${NC}"
else
    ADMIN_KEY=$(openssl rand -base64 32)
    echo "$ADMIN_KEY" > "$ADMIN_KEY_FILE"
    chmod 600 "$ADMIN_KEY_FILE"
    echo -e "${GREEN}✓ Сгенерирован новый ключ и сохранён в $ADMIN_KEY_FILE${NC}"
    echo -e "${RED}⚠️  СОХРАНИТЕ ЭТОТ ФАЙЛ В НАДЁЖНОМ МЕСТЕ!${NC}"
    echo -e "   Ключ: $ADMIN_KEY"
fi

# --- 4. Создание скрипта администратора ---
echo -e "${YELLOW}[4/5] Создание start-admin.sh...${NC}"
cat > start-admin.sh << EOF
#!/bin/bash
# Администратор сети BeySoN-VPN
# Запускать из папки $WORKDIR

ADMIN_KEY=\$(cat $WORKDIR/admin.key)

easytier-core \\
  --network-name "BeySoN-VPN" \\
  --network-secret "Asdf1234" \\
  --secure-mode \\
  --local-private-key "\$ADMIN_KEY" \\
  --dhcp \\
  -e tcp://qwe.p8.ink:11010 \\
  -e tcp://37.221.197.17:11010 \\
  --credential-file $WORKDIR/credentials.json
EOF
chmod +x start-admin.sh
echo -e "${GREEN}✓ start-admin.sh создан${NC}"

# --- 5. Создание скрипта генерации приглашений ---
echo -e "${YELLOW}[5/5] Создание generate-invite.sh...${NC}"
cat > generate-invite.sh << 'EOF'
#!/bin/bash
# Генерирует приглашение и сохраняет в guest.cred
# Использование: ./generate-invite.sh [срок, например 30d]

TTL=${1:-30d}
echo "Генерация приглашения на $TTL ..."

OUTPUT=$(easytier-cli credential generate --ttl "$TTL")
SECRET=$(echo "$OUTPUT" | grep -o '"secret": *"[^"]*"' | cut -d'"' -f4)

if [[ -z "$SECRET" ]]; then
    echo "Ошибка: не удалось получить ключ."
    exit 1
fi

echo "$SECRET" > guest.cred
chmod 600 guest.cred
echo "Приглашение сохранено в guest.cred"
echo "Скопируйте этот ключ гостю:"
echo "$SECRET"
EOF
chmod +x generate-invite.sh
echo -e "${GREEN}✓ generate-invite.sh создан${NC}"

# --- 6. Создание скрипта для гостя ---
echo -e "${YELLOW}[6/5] Создание start-guest.sh...${NC}"
cat > start-guest.sh << 'EOF'
#!/bin/bash
# Запуск гостя. Ключ можно передать аргументом или прочитать из guest.cred

if [[ $# -ge 1 ]]; then
    GUEST_CREDENTIAL="$1"
else
    if [[ -f guest.cred ]]; then
        GUEST_CREDENTIAL=$(cat guest.cred)
    else
        echo "Ошибка: не указан ключ и нет файла guest.cred"
        echo "Использование: $0 <ключ_приглашения>"
        exit 1
    fi
fi

easytier-core \
  --network-name "BeySoN-VPN" \
  --credential "$GUEST_CREDENTIAL" \
  --dhcp \
  -e tcp://qwe.p8.ink:11010 \
  -e tcp://37.221.197.17:11010
EOF
chmod +x start-guest.sh
echo -e "${GREEN}✓ start-guest.sh создан${NC}"

# --- Финальные инструкции ---
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}  🚀 ВСЁ ГОТОВО!${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
echo -e "Теперь вам нужно ЗАПУСТИТЬ АДМИНИСТРАТОРА в фоне."
echo -e "У вас один терминал, поэтому используйте screen:"
echo ""
echo -e "1️⃣  Создайте screen-сессию:"
echo -e "   ${YELLOW}screen -S easytier-admin${NC}"
echo ""
echo -e "2️⃣  Внутри сессии запустите администратора:"
echo -e "   ${YELLOW}cd $WORKDIR && ./start-admin.sh${NC}"
echo ""
echo -e "3️⃣  Отключитесь от screen (не закрывая сессию):"
echo -e "   ${YELLOW}Ctrl+A, затем D${NC}"
echo ""
echo -e "4️⃣  Теперь в основном терминале вы можете генерировать приглашения:"
echo -e "   ${YELLOW}cd $WORKDIR && ./generate-invite.sh 30d${NC}"
echo ""
echo -e "5️⃣  Отправьте полученный ключ гостю."
echo -e "    Гость запускает: ${YELLOW}./start-guest.sh <ключ>${NC}"
echo ""
echo -e "6️⃣  Управление приглашениями:"
echo -e "   ${YELLOW}easytier-cli credential list${NC}"
echo -e "   ${YELLOW}easytier-cli credential revoke <ID>${NC}"
echo ""
echo -e "🔹 Чтобы вернуться в screen-сессию позже:"
echo -e "   ${YELLOW}screen -r easytier-admin${NC}"
echo ""
echo -e "${GREEN}==============================================${NC}"