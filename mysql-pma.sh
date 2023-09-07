#!/bin/bash

# MIT License
# 
# Copyright (c) 2023 Rmly <hello@rmly.dev>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# TODO:
# - add ipv6 validation when using let's encrypt ssl
# - improve input validation
# - improve os detection
# - detect phpMyAdmin latest version and download it, if can't detect it, fallback to hardcoded url
# - open port with ufw if installed, otherwise with iptables

set -e # exit on errors

function nginx_enable_and_test () {
  ln -s /etc/nginx/sites-available/$1 /etc/nginx/sites-enabled/$1

  systemctl restart nginx
}

if [[ "$EUID" -ne 0 ]]; then
  echo "[!] ERROR: This script must be run as root."
  echo "[!] Try running \"sudo su\" and then run the script again."
  exit 1
fi

if [[ ! $(command -v apt) ]]; then
  echo "[!] ERROR: Unsupported operating system."
  echo "[!] This script only supports Debian-based Linux distributions."
  exit 1
fi

apt update

echo
echo "[*] Welcome to Rmly's installation script for MariaDB, MySQL and phpMyAdmin!"
echo "[*] This script will install a database server of your choice and optionally, phpMyAdmin to easily manage your databases."
echo
echo "[*] You may press CTRL+C at any time to abort the installation process."
echo "[*] Note that it may leave your system in an unstable state if you do so during the installation process."
echo

echo "[*] The script will now ask you some questions and then it will proceed with the installation process."
echo

read -s -p "[*] Press enter to continue."
echo

read -p "[?] Do you want to create a database administrative user? (y/n) [y] " yn

case $yn in
  [nN]* )
    db_create_user=false
    ;;
  * )
    db_create_user=true
    ;;
esac

if [[ $db_create_user == true ]]; then
  while [[ -z "$db_create_user_validation" ]]; do
    read -p "[?] Enter the desired user name: (allowed: a-z, 0-9, 12 chars max) " db_user

    if [[ ! "$db_user" =~ ^[a-z0-9]+$ || ${#db_user} -gt 12 ]]; then
      echo "[!] Invalid username, please try again."
    else
      db_create_user_validation=true
    fi
  done

  prompt="[?] Enter password for user "$db_user" (or press enter for a randomly generated password): "
  while IFS= read -p "$prompt" -r -s -n 1 char; do
    if [[ $char == $'\0' ]]; then
      break
    fi
      prompt='*'
      db_user_password+="$char"
  done

  echo

  if [ -z "$db_user_password" ]; then
    db_user_password=$(openssl rand -base64 32 | tr -d '/+=')
  fi
fi

echo "[*] A clean install will remove any current installations of MariaDB/MySQL, PHP, Certbot and NGINX."
read -p "[?] Do you want to perform a clean install? (y/n) [y] " yn

case $yn in
  [nN]* )
    clean_install=false
    ;;
  * )
    clean_install=true
    ;;
esac

echo "[*] phpMyAdmin is a web administration tool for MySQL and MariaDB."
read -p "[?] Do you want to install phpMyAdmin? (y/n) [y] " yn

case $yn in
  [nN]* )
    pma=false
    ;;
  * )
    pma=true
    ;;
esac

menu=("MariaDB (recommended)" "MySQL")
PS3="[?] Which database server do you want to install? (enter the number): "

while [[ -z "$db_server" ]]; do
  select choice in "${menu[@]}"; do
    case $REPLY in
      1)
        db_server="mariadb"
        ;;
      2)
        db_server="mysql"
        ;;
      *)
        echo "[!] Invalid option, please select a valid option in order to continue."
        ;;

    esac
    # Exit the select loop when a valid option is selected
    [[ -n "$db_server" ]] && break
  done
done

if [[ "$pma" == true ]]; then
  menu=("Self-signed certificate" "Let's Encrypt certificate" "No SSL")
  PS3="[?] Which method do you want to use for SSL certificates? (enter the number): "

  while [[ -z "$ssl" ]]; do
    select choice in "${menu[@]}"; do
      case $REPLY in
        1)
          ssl="selfsigned"
          ;;
        2)
          ssl="letsencrypt"
          ;;
        3)
          ssl=false
          ;;
        *)
          echo "[!] Invalid option, please select a valid option in order to continue."
          ;;
      esac
      # Exit the select loop when a valid option is selected
      [[ -n "$ssl" ]] && break
  done
done

  if [[ "$ssl" == "letsencrypt" ]]; then
    apt install curl dnsutils -y

    public_ipv4=$(curl -s 'https://1.1.1.1/cdn-cgi/trace' | grep -oP 'ip=\K[^ ]+')

    echo "[*] Now you need to provide a DNS for your phpMyAdmin installation (e.g pma.yourdomain.com)"
    echo "[*] This is needed in order to create the Let's Encrypt SSL certificate."
    echo "[*] The DNS must point to this server's public IPv4 address."
    
    while [[ -z "$ssl_dns_check" ]]; do
      read -p "[?] Enter DNS for your phpMyAdmin installation (e.g pma.yourdomain.com) " ssl_domain

      dns_lookup=$(dig @1.1.1.1 +short "$ssl_domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

      #dns_lookup=$public_ipv4 # debug
      if [[ "$dns_lookup" != "$public_ipv4" ]]; then
        echo "[!] $ssl_domain points to $dns_lookup. It must point to $public_ipv4."
      else
        ssl_dns_check=true
      fi
    done

  elif [[ "$ssl" == "selfsigned" || "$ssl" == false ]]; then
    while [[ -z "$nginx_server_name" ]]; do
      read -p "[?] Enter NGINX servername (e.g pma.yourdomain.com) " nginx_server_name
    done
  fi
fi

echo "[*] Installation summary:"
echo "-  Database server: $db_server"
echo "-  Database administrative user: $db_user"
echo "-- Database administrative user password: $db_user_password"
echo "-  Clean install: $clean_install"
echo "-  phpMyAdmin: $pma"
echo "-  SSL: $ssl"
echo "-- SSL Domain: $ssl_domain"
echo "-- NGINX server name: $nginx_server_name"

read -s -p "[*] Press enter to start the installation."
echo

echo "[*] Installation started... Please wait, this may take some time."

if [[ "$clean_install" == true ]]; then
  echo "[*] Clean installation specified, running uninstall script."

  apt install curl -y

  curl -s 'https://raw.githubusercontent.com/Rmlyy/mysql-pma/main/mysql-pma-uninstall.sh' | bash
fi

echo "[*] Installing $db_server server..."
if [[ "$db_server" == "mariadb" ]]; then
  apt install mariadb-server -y
elif [[ "$db_server" == "mysql" ]]; then
  apt install default-mysql-server -y
fi

echo "[*] Running mysql_secure_installation, please answer the questions."
mysql_secure_installation

if [[ ! -z "$db_user" ]]; then
  echo "[*] Creating administrative database user \"$db_user\"."
  mysql -uroot -e "CREATE USER '$db_user'@'%' IDENTIFIED BY '$db_user_password';"
  mysql -uroot -e "GRANT ALL ON *.* TO '$db_user'@'%' WITH GRANT OPTION;"

  wd=$(pwd)
  credentials_file="$wd/database-credentials.txt"

  echo "$db_user:$db_user_password" > $credentials_file
  echo "[*] Database user and password have been saved to $credentials_file."
fi

if [[ "$pma" == true ]]; then
  echo "[*] Installing phpMyAdmin..."
  apt install nginx php-fpm php-mbstring php-xml php-mysql unzip wget -y

  pma_archive_name="pma.zip"
  pma_base_path="/opt"
  pma_install_path="$pma_base_path/pma"
  pma_archive_path="$pma_base_path/$pma_archive_name"
  pma_archive_url="https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip"

  if [[ ! -d "$pma_base_path" ]]; then
    mkdir -p "$pma_base_path"
  fi

  wget -O "$pma_archive_path" "$pma_archive_url"

  pma_archive_dir_name=$(unzip -ql "$pma_archive_path" | awk 'NF > 3 && $4 ~ /\/$/ {sub(/\/$/, "", $4); print $4; exit}')

  if [[ -z "$pma_archive_dir_name" ]]; then
    echo "[!] ERROR: Unable to find phpMyAdmin directory."
    exit 1
  fi

  unzip "$pma_archive_path" -d "$pma_base_path"
  rm -rf "$pma_archive_path"

  mv "$pma_base_path/$pma_archive_dir_name" "$pma_install_path"
  mv "$pma_install_path/config.sample.inc.php" "$pma_install_path/config.inc.php"

  blowfish_secret=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

  sed -i "s|\$cfg\['blowfish_secret'\] = '';|\$cfg\['blowfish_secret'\] = '$blowfish_secret';|" "$pma_install_path/config.inc.php"

  nginx_config_path="/etc/nginx/nginx.conf"

  if [[ ! -f "$nginx_config_path" ]]; then
    echo "[!] ERROR: nginx configuration file not found at $nginx_config_path"
    exit 1
  fi

  nginx_user=$(grep -oP '^\s*user\s+\K[^;]+' $nginx_config_path)

  chown -R $nginx_user:$nginx_user $pma_install_path

  php_version=$(php -v | awk '/PHP/ {split($2, a, "."); print a[1] "." a[2]}' | grep -o '^[0-9.]*')

  if [[ -z "$php_version" ]]; then
    echo "[!] ERROR: Couldn't detect the current PHP version."
    exit 1
  fi
fi

if [[ "$ssl" == "letsencrypt" ]]; then
  echo "[*] Issuing Let's encrypt SSL certificate for $ssl_domain"

  cat <<EOL > "/etc/nginx/sites-available/$ssl_domain"
server {
  listen 80;
  listen [::]:80;
  server_name $ssl_domain;

  root $pma_install_path;
  index index.html index.php;

  location / {
    try_files \$uri \$uri/ =404;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php$php_version-fpm.sock;
  }
}
EOL

  nginx_enable_and_test "$ssl_domain"

  apt install python3-certbot-nginx -y
  certbot --nginx --register-unsafely-without-email --agree-tos -d "$ssl_domain"

elif [[ "$ssl" == "selfsigned" ]]; then
  echo "[*] Generating self-signed SSL certificate."

  selfsigned_key_path="/etc/ssl/private/pma-selfsigned.key"
  selfsigned_cert_path="/etc/ssl/certs/pma-selfsigned.crt"

  apt install openssl -y
  openssl req -x509 -nodes -days 3652 -newkey rsa:2048 -subj "/CN=$nginx_server_name/O=Rmly's MySQL and PMA install script./C=US" -keyout $selfsigned_key_path -out $selfsigned_cert_path

  cat <<EOL > "/etc/nginx/sites-available/$nginx_server_name"
server {
  listen 443 ssl http2;
  listen [::]:443 ssl http2;
  server_name $nginx_server_name;

  ssl_certificate $selfsigned_cert_path;
  ssl_certificate_key $selfsigned_key_path;

  root $pma_install_path;
  index index.html index.php;

  location / {
    try_files \$uri \$uri/ =404;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php$php_version-fpm.sock;
  }
}
EOL

  nginx_enable_and_test "$nginx_server_name"

elif [[ "$ssl" == false ]]; then
  echo "[*] Configuring nginx with no SSL."

  cat <<EOL > "/etc/nginx/sites-available/$nginx_server_name"
server {
  listen 80;
  listen [::]:80;
  server_name $nginx_server_name;

  root $pma_install_path;
  index index.html index.php;

  location / {
    try_files \$uri \$uri/ =404;
  }

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php$php_version-fpm.sock;
  }
}
EOL

  nginx_enable_and_test "$nginx_server_name"
fi

echo "[*] Script execution finished. Everything should be successfully installed."