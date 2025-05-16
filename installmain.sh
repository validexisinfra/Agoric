#!/bin/bash

set -e

# Цвета
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

print() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Ввод от пользователя
read -p "Enter your node MONIKER: " MONIKER
read -p "Enter your custom port prefix (e.g. 16): " CUSTOM_PORT

print "Installing Agoric Node with moniker: $MONIKER"
print "Using custom port prefix: $CUSTOM_PORT"

# Установка зависимостей
print "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y curl git build-essential lz4 wget

# Установка Node.js LTS и npm
print "Installing Node.js LTS and npm..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Проверка установки node
if ! command -v node &> /dev/null; then
  print_error "Node.js installation failed"
  exit 1
fi

# Установка yarn
print "Installing yarn..."
sudo npm install -g yarn

# Проверка установки yarn
if ! command -v yarn &> /dev/null; then
  print_error "Yarn installation failed"
  exit 1
fi

# Клонирование репозитория Agoric
cd $HOME
rm -rf agoric-upgrade-19
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-19
cd agoric-upgrade-19
git checkout agoric-upgrade-19

# Установка JS-зависимостей и сборка
print "Installing JavaScript dependencies and building..."
yarn install && yarn build
(cd packages/cosmic-swingset && make)

# Конфигурация узла
agd config chain-id agoric-3
agd config keyring-backend file
agd config node tcp://localhost:${CUSTOM_PORT}57
agd init "$MONIKER" --chain-id agoric-3

# Генезис и addrbook
curl -Ls https://snapshots.kjnodes.com/agoric/genesis.json > $HOME/.agoric/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/agoric/addrbook.json > $HOME/.agoric/config/addrbook.json

# Сиды
sed -i.bak -e "s|^seeds *=.*|seeds = \"400f3d9e30b69e78a7fb891f60d76fa3c73f0ecc@agoric.rpc.kjnodes.com:12759\"|" $HOME/.agoric/config/config.toml

# Минимальная цена за газ
sed -i.bak -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.025ubld\"|" $HOME/.agoric/config/app.toml

# Настройка pruning
sed -i.bak \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.agoric/config/app.toml

# Отключение fastnode
sed -i.bak -e 's|^iavl-disable-fastnode *=.*|iavl-disable-fastnode = true|' $HOME/.agoric/config/app.toml

# Порты (config.toml)
sed -i.bak -e "s%:26658%:${CUSTOM_PORT}58%g;
s%:26657%:${CUSTOM_PORT}57%g;
s%:26656%:${CUSTOM_PORT}56%g;
s%:6060%:${CUSTOM_PORT}60%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${CUSTOM_PORT}56\"%;
s%:26660%:${CUSTOM_PORT}66%g" $HOME/.agoric/config/config.toml

# Порты (app.toml)
sed -i.bak -e "s%:1317%:${CUSTOM_PORT}17%g;
s%:8080%:${CUSTOM_PORT}80%g;
s%:9090%:${CUSTOM_PORT}90%g;
s%:9091%:${CUSTOM_PORT}91%g;
s%:8545%:${CUSTOM_PORT}45%g;
s%:8546%:${CUSTOM_PORT}46%g" $HOME/.agoric/config/app.toml

# Создание systemd сервиса
sudo tee /etc/systemd/system/agoricd.service > /dev/null <<EOF
[Unit]
Description=Agoric Node
After=network-online.target

[Service]
User=${USER}
ExecStart=$(which agd) start --home ${HOME}/.agoric
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Загрузка snapshot
print "Downloading snapshot..."
curl -o - -L https://snapshots.polkachu.com/snapshots/agoric/agoric_19673131.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/.agoric

# Запуск сервиса
sudo systemctl daemon-reload
sudo systemctl enable agoricd
sudo systemctl start agoricd

print "✅ Установка завершена. Логи: 'journalctl -u agoricd -f -o cat'"
