#!/bin/bash
set -e

# Colors for output
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

print() {
  echo -e "${GREEN}$1${NC}"
}

print_error() {
  echo -e "${RED}$1${NC}"
}

# Prompt for MONIKER
read -p "Enter your MONIKER: " MONIKER

# Prompt for CUSTOM_PORT
read -p "Enter your custom port prefix (e.g., 166): " CUSTOM_PORT

# Clone project repository
cd $HOME
rm -rf agoric-upgrade-19
print "Cloning Agoric SDK..."
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-19
cd agoric-upgrade-19
git checkout agoric-upgrade-19

# Install and build Agoric Javascript packages
print "Installing JS dependencies..."
yarn install && yarn build

# Install and build Agoric Cosmos SDK support
print "Building cosmic-swingset..."
(cd packages/cosmic-swingset && make)

# Setup config
print "Setting up node config..."
agd config chain-id agoric-3
agd config keyring-backend file
agd config node tcp://localhost:${CUSTOM_PORT}57

# Initialize the node
agd init "$MONIKER" --chain-id agoric-3

# Download genesis and addrbook
curl -Ls https://snapshots.kjnodes.com/agoric/genesis.json > $HOME/.agoric/config/genesis.json
curl -Ls https://snapshots.kjnodes.com/agoric/addrbook.json > $HOME/.agoric/config/addrbook.json

# Add seeds
SEEDS="400f3d9e30b69e78a7fb891f60d76fa3c73f0ecc@agoric.rpc.kjnodes.com:12759"
sed -i -e "s|^seeds *=.*|seeds = \"$SEEDS\"|" $HOME/.agoric/config/config.toml

# Set minimum gas price
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.025ubld\"|" $HOME/.agoric/config/app.toml

# Set pruning
sed -i \
  -e 's|^pruning *=.*|pruning = "custom"|' \
  -e 's|^pruning-keep-recent *=.*|pruning-keep-recent = "100"|' \
  -e 's|^pruning-keep-every *=.*|pruning-keep-every = "0"|' \
  -e 's|^pruning-interval *=.*|pruning-interval = "19"|' \
  $HOME/.agoric/config/app.toml

# Disable fastnode
sed -i -e 's|^iavl-disable-fastnode *=.*|iavl-disable-fastnode = true|' $HOME/.agoric/config/app.toml

# Set custom ports in config.toml
sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:${CUSTOM_PORT}58\"%; \
            s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:${CUSTOM_PORT}57\"%; \
            s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:${CUSTOM_PORT}60\"%; \
            s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:${CUSTOM_PORT}56\"%; \
            s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":${CUSTOM_PORT}66\"%" \
            $HOME/.agoric/config/config.toml

# Set custom ports in app.toml
sed -i -e "s%^address = \"tcp://0.0.0.0:1317\"%address = \"tcp://0.0.0.0:${CUSTOM_PORT}17\"%; \
            s%^address = \"\:8080\"%address = \"\:${CUSTOM_PORT}80\"%; \
            s%^address = \"0.0.0.0:9090\"%address = \"0.0.0.0:${CUSTOM_PORT}90\"%; \
            s%^address = \"0.0.0.0:9091\"%address = \"0.0.0.0:${CUSTOM_PORT}91\"%; \
            s%^address = \"0.0.0.0:8545\"%address = \"0.0.0.0:${CUSTOM_PORT}45\"%; \
            s%^ws-address = \"0.0.0.0:8546\"%ws-address = \"0.0.0.0:${CUSTOM_PORT}46\"%" \
            $HOME/.agoric/config/app.toml

# Re-configure node with new port
agd config node tcp://localhost:${CUSTOM_PORT}57

# Create service
print "Creating systemd service..."
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

# Download and extract snapshot
#print "Downloading chain snapshot..."
#curl -L https://snapshots.kjnodes.com/agoric/snapshot_latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.agoric

# Start the node
print "Enabling and starting agoricd service..."
sudo systemctl daemon-reload
sudo systemctl enable agoricd
sudo systemctl start agoricd

print "Setup complete. Use 'journalctl -u agoricd -f -o cat' to view logs."
