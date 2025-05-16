# Agoric
Agoric is a secure JavaScript programming platform that makes it easy to create blockchain and smart contracts.

# 🪙 Agoric Setup & Upgrade Scripts

A collection of automated scripts for setting up and upgrading Agoric nodes on **Mainnet (agoric-3)**.

---

### ⚙️ Validator  Node Setup  
Install a full Agoric validator node with custom ports, snapshot import, and systemd configuration.

```bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/Agoric/main/installmain.sh)

---

### 🔄 Validator Node Upgrade 
Update your agd binary and restart the systemd service safely.

```bash
source <(curl -s https://raw.githubusercontent.com/validexisinfra/Agoric/main/upgrademain.sh)
