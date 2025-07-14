#!/bin/bash
cd $HOME
rm -rf agoric-upgrade-21
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-21
cd agoric-upgrade-21
git checkout agoric-upgrade-21
​
yarn install && yarn build
(cd packages/cosmic-swingset && make)
​
sudo systemctl restart agoricd && sudo journalctl -fu agoricd -o cat
