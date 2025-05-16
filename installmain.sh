#!/bin/bash

set -e

# Colors
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

print() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Ask for moniker
read -p "Enter your node MONIKER: " MONIKER

# Ask for custom port prefix
read -p "Enter your custom port prefix (e.g. 16): " CUSTOM_PORT

print "Installing Agoric Node with moniker: $MONIKER"
print "Using custom port prefix: $CUSTOM_PORT"

# Clone Agoric repo
cd $HOME
rm -rf agoric-upgrade-19
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-19
cd agoric-upgrade-19
git checkout agoric-upgrade-19

# Install dependencies
yarn install && yarn build
(cd packages/cosmic-swingset && make)

# Configure node
agd config chain-id agoric-3
agd config keyring-backend file
agd config node tcp://localhost:${CUSTOM_PORT}57
agd init "$MONIKER" --chain-id agoric-3

# Download genesis and addrbook
curl -Ls https://snapshots.kjnodes.com/agoric/genesis.json > $HOME/.agoric/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/agoric/addrbook.json > $HOME/.agoric/config/addrbook.json

# Set seeds
sed -i.bak -e "s|^seeds *=.*|seeds = \"400f3d9e30b69e78a7fb891f60d76fa3c73f0ecc@agoric.rpc.kjnodes.com:12759\"|" $HOME/.agoric/config/config.toml

# Set minimum gas price
sed -i.bak -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.025ubld\"|" $HOME/.agoric/config/app.toml

# Enable pruning
sed -i.bak \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.agoric/config/app.toml

# Disable fastnode
sed -i.bak -e 's|^iavl-disable-fastnode *=.*|iavl-disable-fastnode = true|' $HOME/.agoric/config/app.toml

# Set custom ports in config.toml
sed -i.bak -e "s%:26658%:${CUSTOM_PORT}58%g;
s%:26657%:${CUSTOM_PORT}57%g;
s%:26656%:${CUSTOM_PORT}56%g;
s%:6060%:${CUSTOM_PORT}60%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${CUSTOM_PORT}56\"%;
s%:26660%:${CUSTOM_PORT}66%g" $HOME/.agoric/config/config.toml

# Set custom ports in app.toml
sed -i.bak -e "s%:1317%:${CUSTOM_PORT}17%g;
s%:8080%:${CUSTOM_PORT}80%g;
s%:9090%:${CUSTOM_PORT}90%g;
s%:9091%:${CUSTOM_PORT}91%g;
s%:8545%:${CUSTOM_PORT}45%g;
s%:8546%:${CUSTOM_PORT}46%g" $HOME/.agoric/config/app.toml

# Create systemd service
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

# Download snapshot
curl -o - -L https://snapshots.polkachu.com/snapshots/agoric/agoric_19673131.tar.lz4 | lz4 -c -d - | tar -x -C $HOME/.agoric

# Start service
sudo systemctl daemon-reload
sudo systemctl enable agoricd
sudo systemctl start agoricd

print "Setup complete. Use 'journalctl -u agoricd -f -o cat' to view logs."
