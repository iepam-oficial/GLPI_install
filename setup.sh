#!/bin/bash

read -p "Digite o nome do usuário do banco de dados: " DB_USER

while true; do
    read -sp "Digite a senha do banco de dados: " DB_PASS
    echo ""
    read -sp "Confirme a senha do banco de dados: " DB_PASS_CONFIRM
    echo ""
    if [ "$DB_PASS" == "$DB_PASS_CONFIRM" ]; then
        break
    else
        echo "As senhas não coincidem. Tente novamente."
    fi
done

read -p "Digite o nome do domínio do servidor: " SERVER_DOMAIN

LOG_FILE="glpi_install_logs"
touch $LOG_FILE
chmod 600 $LOG_FILE  # Permissões restritas para o arquivo de log
# Função para registrar logs
log() {
    echo "$1" | tee -a $LOG_FILE
}

if [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$SERVER_DOMAIN" ]; then
    log "Erro: Todos os campos devem ser preenchidos."
    exit 1
fi

GLPI_DIR="/var/www/html/glpi"
GLPI_VAR_DIR="/var/lib/glpi"
GLPI_LOG_DIR="/var/log/glpi"
APACHE_CONF="/etc/apache2/conf-available/glpi.conf"
PHP_INI="/etc/php/8.3/apache2/php.ini"

log "Atualizando lista de pacotes..."
if ! apt update | tee -a $LOG_FILE; then
    log "Erro ao atualizar pacotes. Abortando."
    exit 1
fi

if ! apt upgrade -y | tee -a $LOG_FILE; then
    log "Erro ao atualizar pacotes. Abortando."
    exit 1
fi

log "Instalando pacotes para manipulação de arquivos..."
if ! apt install -y xz-utils bzip2 unzip curl | tee -a $LOG_FILE; then
    log "Erro ao instalar pacotes. Abortando."
    exit 1
fi

log "Adicionando repositório para PHP 8.3..."
if ! add-apt-repository ppa:ondrej/php -y | tee -a $LOG_FILE; then
    log "Erro ao adicionar repositório. Abortando."
    exit 1
fi

log "Instalando PHP 8.3 e extensões..."
if ! apt install -y php8.3 php8.3-cli php8.3-common php8.3-curl php8.3-gd php8.3-imap php8.3-ldap php8.3-mysql php8.3-xml php8.3-mbstring php8.3-bcmath php8.3-intl php8.3-zip php8.3-redis php8.3-bz2 | tee -a $LOG_FILE; then
    log "Erro ao instalar PHP. Abortando."
    exit 1
fi

log "Atualizando novamente..."
if ! apt upgrade -y | tee -a $LOG_FILE; then
    log "Erro ao atualizar pacotes. Abortando."
    exit 1
fi

log "Verificando versão do PHP..."
php -v | tee -a $LOG_FILE

log "Habilitando módulo PHP no Apache..."
if ! a2enmod php8.3 | tee -a $LOG_FILE; then
    log "Erro ao habilitar módulo PHP. Abortando."
    exit 1
fi

log "Reiniciando Apache..."
if ! systemctl restart apache2 | tee -a $LOG_FILE; then
    log "Erro ao reiniciar Apache. Abortando."
    exit 1
fi

log "Instalando MariaDB..."
if ! apt install -y mariadb-server | tee -a $LOG_FILE; then
    log "Erro ao instalar MariaDB. Abortando."
    exit 1
fi

log "Iniciando e habilitando MariaDB..."
systemctl start mariadb | tee -a $LOG_FILE
systemctl enable mariadb | tee -a $LOG_FILE

log "Configurando banco de dados..."
if ! systemctl is-active --quiet mariadb; then
    log "Erro: MariaDB não está em execução."
    exit 1
fi

sudo mysql -e "CREATE DATABASE glpi CHARACTER SET utf8" | tee -a $LOG_FILE
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'" | tee -a $LOG_FILE
sudo mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO '$DB_USER'@'localhost' WITH GRANT OPTION" | tee -a $LOG_FILE
sudo mysql -e "FLUSH PRIVILEGES;" | tee -a $LOG_FILE

log "Habilitando suporte a timezones no MariaDB..."
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql mysql | tee -a $LOG_FILE
mysql -e "GRANT SELECT ON mysql.time_zone_name TO '$DB_USER'@'localhost';" | tee -a $LOG_FILE

log "Realizando backup de arquivos de configuração..."
cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.bak
cp $PHP_INI ${PHP_INI}.bak

log "Instalando Apache2..."
if ! apt install -y apache2 | tee -a $LOG_FILE; then
    log "Erro ao instalar Apache2. Abortando."
    exit 1
fi

log "Criando arquivo de configuração para o GLPI no Apache..."
cat > $APACHE_CONF << EOF
<VirtualHost *:80>
    ServerName $SERVER_DOMAIN
    DocumentRoot $GLPI_DIR/public
    <Directory $GLPI_DIR/public>
        AllowOverride All
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
</VirtualHost>
EOF

log "Habilitando módulo rewrite do Apache..."
a2enmod rewrite | tee -a $LOG_FILE
log "Habilitando configuração para o GLPI..."
a2enconf glpi.conf | tee -a $LOG_FILE

log "Reiniciando Apache..."
if ! systemctl restart apache2 | tee -a $LOG_FILE; then
    log "Erro ao reiniciar Apache. Abortando."
    exit 1
fi

log "Baixando e instalando o GLPI..."
if ! wget -O- https://github.com/glpi-project/glpi/releases/download/10.0.16/glpi-10.0.16.tgz | tar -zxv -C /var/www/html/ | tee -a $LOG_FILE; then
    log "Erro ao baixar e instalar o GLPI. Abortando."
    exit 1
fi

log "Ajustando permissões de arquivos do GLPI..."
chown root:root /var/www/html/ -Rf | tee -a $LOG_FILE
chown www-data:www-data $GLPI_VAR_DIR -Rf | tee -a $LOG_FILE
chown www-data:www-data /etc/glpi -Rf | tee -a $LOG_FILE
chown www-data:www-data $GLPI_DIR/marketplace -Rf | tee -a $LOG_FILE
chown www-data:www-data /var/www/html/ -Rf | tee -a $LOG_FILE

log "Ajustando permissões gerais..."
find /var/www/html/ -type d -exec chmod 755 {} \; | tee -a $LOG_FILE
find /var/www/html/ -type f -exec chmod 644 {} \; | tee -a $LOG_FILE

log "Criando diretório de logs para o GLPI..."
mkdir -p $GLPI_LOG_DIR | tee -a $LOG_FILE
chown -R www-data:www-data $GLPI_LOG_DIR | tee -a $LOG_FILE
chmod -R 755 $GLPI_LOG_DIR | tee -a $LOG_FILE

log "Configurando segurança para sessões no PHP..."
sed -i "s/;session.cookie_httponly =/session.cookie_httponly = on/" $PHP_INI | tee -a $LOG_FILE

log "Reiniciando Apache..."
if ! systemctl restart apache2 | tee -a $LOG_FILE; then
    log "Erro ao reiniciar Apache. Abortando."
    exit 1
fi

log "Instalação concluída com sucesso!"
