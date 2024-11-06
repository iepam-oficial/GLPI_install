#!/bin/bash

# Solicitar confirmação antes de prosseguir
read -p "Tem certeza de que deseja desinstalar e limpar o GLPI (sim/não)? " CONFIRMATION
if [[ "$CONFIRMATION" != "sim" ]]; then
    echo "Desinstalação cancelada."
    exit 1
fi

# Solicitar informações de usuário e banco de dados
read -p "Digite o nome do banco de dados GLPI: " DB_NAME
read -p "Digite o nome do usuário do banco de dados GLPI: " DB_USER
read -sp "Digite a senha do usuário do banco de dados GLPI: " DB_PASS
echo

# Arquivo de log
LOG_FILE="glpi_uninstall_logs"

# Função para registrar logs
log() {
    echo "$1" | tee -a $LOG_FILE
}

# Parar o Apache
log "Parando o Apache..."
systemctl stop apache2 | tee -a $LOG_FILE

# Remover o diretório do GLPI
log "Removendo diretórios do GLPI..."
rm -rf /var/www/html/glpi | tee -a $LOG_FILE
rm -rf /var/lib/glpi | tee -a $LOG_FILE
rm -rf /etc/glpi | tee -a $LOG_FILE
rm -rf /var/log/glpi | tee -a $LOG_FILE

# Remover configuração do Apache para o GLPI
log "Removendo configuração do Apache para o GLPI..."
rm -f /etc/apache2/conf-available/glpi.conf | tee -a $LOG_FILE
a2disconf glpi.conf | tee -a $LOG_FILE

# Reiniciar o Apache
log "Reiniciando Apache..."
systemctl restart apache2 | tee -a $LOG_FILE

# Remover o banco de dados GLPI
log "Removendo banco de dados GLPI..."
mysql -u root -p -e "DROP DATABASE IF EXISTS $DB_NAME;" | tee -a $LOG_FILE

# Remover o usuário do banco de dados GLPI
log "Removendo usuário do banco de dados GLPI..."
mysql -u root -p -e "DROP USER IF EXISTS '$DB_USER'@'localhost';" | tee -a $LOG_FILE
mysql -u root -p -e "FLUSH PRIVILEGES;" | tee -a $LOG_FILE

# Remover o MariaDB se não for mais necessário
read -p "Deseja remover o MariaDB (sim/não)? " REMOVE_MARIADB
if [[ "$REMOVE_MARIADB" == "sim" ]]; then
    log "Removendo MariaDB..."
    apt purge -y mariadb-server mariadb-client | tee -a $LOG_FILE
    apt autoremove -y | tee -a $LOG_FILE
    rm -rf /var/lib/mysql /etc/mysql /var/log/mysql | tee -a $LOG_FILE
fi

# Remover o PHP se não for mais necessário
read -p "Deseja remover o PHP (sim/não)? " REMOVE_PHP
if [[ "$REMOVE_PHP" == "sim" ]]; then
    log "Removendo PHP..."
    apt purge -y php* | tee -a $LOG_FILE
    apt autoremove -y | tee -a $LOG_FILE
    rm -rf /etc/php | tee -a $LOG_FILE
fi

# Remover o Apache se não for mais necessário
read -p "Deseja remover o Apache (sim/não)? " REMOVE_APACHE
if [[ "$REMOVE_APACHE" == "sim" ]]; then
    log "Removendo Apache..."
    apt purge -y apache2 | tee -a $LOG_FILE
    apt autoremove -y | tee -a $LOG_FILE
    rm -rf /etc/apache2 | tee -a $LOG_FILE
fi

log "Desinstalação e limpeza do GLPI concluídas com sucesso."
