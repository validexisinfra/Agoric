#!/bin/bash

set -e

GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

print() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

read -p "Enter your node MONIKER: " MONIKER
read -p "Enter your custom port prefix (e.g. 16): " CUSTOM_PORT

print "Installing Agoric Node with moniker: $MONIKER"
print "Using custom port prefix: $CUSTOM_PORT"

print "Updating system and installing dependencies..."
sudo apt update
sudo apt install -y curl git build-essential lz4 wget

curl -fsSL https://deb.nodesource.com/setup_18.x | sudo bash -

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt update
sudo apt remove -y nodejs
sudo apt autoremove -y

sudo apt install -y nodejs=18.* yarn

sudo rm -rf /usr/local/go
curl -Ls https://go.dev/dl/go1.23.6.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
eval $(echo 'export PATH=$PATH:/usr/local/go/bin' | sudo tee /etc/profile.d/golang.sh)
eval $(echo 'export PATH=$PATH:$HOME/go/bin' | tee -a $HOME/.profile)
echo "export PATH=$PATH:/usr/local/go/bin:/usr/local/bin:$HOME/go/bin" >> $HOME/.bash_profile
source $HOME/.bash_profile

cd $HOME
rm -rf agoric-upgrade-19
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-19
cd agoric-upgrade-19
git checkout agoric-upgrade-19

print "Installing JavaScript dependencies and building..."
yarn install && yarn build
(cd packages/cosmic-swingset && make)

agd config chain-id agoric-3
agd config keyring-backend file
agd config node tcp://localhost:${CUSTOM_PORT}657
agd init "$MONIKER" --chain-id agoric-3

curl -Ls https://snapshots.kjnodes.com/agoric/genesis.json > $HOME/.agoric/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/agoric/addrbook.json > $HOME/.agoric/config/addrbook.json

sed -i.bak -e "s|^seeds *=.*|seeds = \"400f3d9e30b69e78a7fb891f60d76fa3c73f0ecc@agoric.rpc.kjnodes.com:12759\"|" $HOME/.agoric/config/config.toml

sed -i.bak -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.025ubld\"|" $HOME/.agoric/config/app.toml

sed -i.bak \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.agoric/config/app.toml

sed -i.bak -e 's|^iavl-disable-fastnode *=.*|iavl-disable-fastnode = true|' $HOME/.agoric/config/app.toml

sed -i.bak -e "s%:26658%:${CUSTOM_PORT}658%g;
s%:26657%:${CUSTOM_PORT}657%g;
s%:26656%:${CUSTOM_PORT}656%g;
s%:6060%:${CUSTOM_PORT}060%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${CUSTOM_PORT}56\"%;
s%:26660%:${CUSTOM_PORT}660%g" $HOME/.agoric/config/config.toml

sed -i.bak -e "s%:1317%:${CUSTOM_PORT}17%g;
s%:8080%:${CUSTOM_PORT}080%g;
s%:9090%:${CUSTOM_PORT}090%g;
s%:9091%:${CUSTOM_PORT}091%g;
s%:8545%:${CUSTOM_PORT}545%g;
s%:8546%:${CUSTOM_PORT}546%g" $HOME/.agoric/config/app.toml

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

print "Downloading snapshot..."
curl -o - -L https://snapshots.polkachu.com/snapshots/agoric/agoric_19673131.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/.agoric

sudo systemctl daemon-reload
sudo systemctl enable agoricd
sudo systemctl start agoricd

print "✅ Setup complete. Use 'journalctl -u agoricd -f -o cat' to view logs"
