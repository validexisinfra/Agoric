#!/bin/bash
cd $HOME
rm -rf agoric-upgrade-19
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-20
cd agoric-upgrade-20
git checkout agoric-upgrade-20
​
yarn install && yarn build
(cd packages/cosmic-swingset && make)
​
sudo systemctl restart agoricd && sudo journalctl -fu agoricd -o cat
