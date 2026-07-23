#!/bin/bash
set -e

echo "=== Установка EasyTier Secure Mode (автоматически) ==="

# 1.  Устанавливаем Docker, если нет
if ! command -v docker &> /dev/null; then
    echo "Устанавливаем Docker..."
    apt update && apt install -y docker.io docker-compose
fi

# 2. Создаём папку
mkdir -p /root/vpn
cd /root/vpn

# 3. Генерируем ключ админа
ADMIN_KEY=$(openssl rand -base64 32)
echo "$ADMIN_KEY" > admin.key
chmod 600 admin.key

# 4. Создаём конфиг (автоматически подставляем ключ)
cat > config.toml <<EOF
dhcp = true
listeners = ["tcp://0.0.0.0:11010", "udp://0.0.0.0:11010"]
credential_file = "/root/vpn/credentials.json"

[network_identity]
network_name = "BeySoN-VPN"
network_secret = "Asdf1234"

[[peer]]
uri = "tcp://qwe.p8.ink:11010"

[[peer]]
uri = "tcp://37.221.197.17:11010"

[secure_mode]
enabled = true
local_private_key = "$ADMIN_KEY"
EOF

# 5. Запускаем контейнер администратора
docker rm -f easytier-admin 2>/dev/null || true
docker run -d \
  --name easytier-admin \
  --restart unless-stopped \
  -p 11010:11010 \
  -v /root/vpn:/root/vpn \
  -w /root/vpn \
  easytier/easytier:latest \
  easytier-core -c config.toml

# 6. Создаём скрипт генерации приглашений
cat > /root/vpn/generate.sh <<'GEN'
#!/bin/bash
docker exec -it easytier-admin easytier-cli credential generate --ttl ${1:-30d}
GEN
chmod +x /root/vpn/generate.sh

# 7. Создаём скрипт для гостя (шаблон)
cat > /root/vpn/guest.sh <<'GUEST'
#!/bin/bash
if [ -z "$1" ]; then
  echo "Использование: $0 <ключ_приглашения>"
  exit 1
fi
easytier-core --network-name "BeySoN-VPN" --credential "$1" --dhcp -e tcp://qwe.p8.ink:11010 -e tcp://37.221.197.17:11010
GUEST
chmod +x /root/vpn/guest.sh

echo "============================================"
echo "✅ Всё готово!"
echo "============================================"
echo ""
echo "🔹 Администратор уже запущен в Docker (порт 11010)."
echo "🔹 Чтобы создать приглашение для нового гостя, выполни:"
echo "   /root/vpn/generate.sh 30d"
echo ""
echo "🔹 Полученный ключ отправь гостю."
echo "🔹 Гость запускает (на своей машине с EasyTier):"
echo "   /root/vpn/guest.sh <ключ>"
echo ""
echo "============================================"