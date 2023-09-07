#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "[!] ERROR: This script must be run as root."
  echo "[!] Try running \"sudo su\" and then run the script again."
  exit 1
fi

if [ ! $(command -v apt) ]; then
  echo "[!] ERROR: Unsupported operating system."
  echo "[!] This script only supports Debian-based Linux distributions."
  exit 1
fi

echo "[*] This script will uninstall MySQL/MariaDB, phpMyAdmin, NGINX, PHP, Certbot."
echo

read -s -p "[*] Press enter to continue."
echo

DEBIAN_FRONTEND=noninteractive apt purge '*mysql*' '*mariadb*' '*php*' '*nginx*' '*certbot*' -y
DEBIAN_FRONTEND=noninteractive apt autoremove --purge -y
rm -rf /opt/pma
rm -rf /etc/mysql
rm -rf /etc/php
rm -rf /etc/letsencrypt
rm -rf /var/www
rm -rf /var/lib/mysql
rm -rf /var/lib/mysql-*