# MySQL & PMA install script

This script installs and configures MySQL/MariaDB, PMA (phpMyAdmin), NGINX and Certbot on your Debian/Ubuntu system.

### Features

- **Database Server Installation**: Choose between MariaDB and MySQL for your database server installation.
- **Database Administrative User**: Create a database administrative user with a customizable username and password.
- **phpMyAdmin Installation**: Optionally install and configure phpMyAdmin, a web administration tool for MySQL and MariaDB.
- SSL Certificate Options
  - Self-signed certificate (Useful for CloudFlare setups)
  - Let's Encrypt certificate
  - No SSL (configure NGINX without SSL)
- **Automatic NGINX Configuration**: Automatically configure NGINX with SSL certificates, including Let's Encrypt integration.

### Supported Operating Systems

Any recent Debian-based distribution should work.

#### Tested Distributions:

- Ubuntu 22.04 LTS

### Usage

Download the script  
Execute it:

```sh
$ sudo bash mysql-pma.sh
```

Answer the questions asked by the script.

### Uninstall

There is also an [uninstall script](mysql-pma-uninstall.sh) you can use to remove everything that this script has installed.

### License

This project is licensed under MIT. See [LICENSE](LICENSE) for more details.
