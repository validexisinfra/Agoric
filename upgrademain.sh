#!/bin/bash
cd $HOME
rm -rf agoric-upgrade-18a
git clone https://github.com/Agoric/agoric-sdk.git agoric-upgrade-19
cd agoric-upgrade-19
git checkout agoric-upgrade-19
​
yarn install && yarn build
(cd packages/cosmic-swingset && make)
​
sudo systemctl restart agoricd && sudo journalctl -fu agoricd -o cat
