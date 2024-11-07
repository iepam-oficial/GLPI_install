Dê permissão de execução ao script.
Para evitar erros execute o script no modo root

Para entrar no modo root execute o comando "sudo su" e digite a senha do usuário root.

Para conceder permissão de execução, execute o script: chmod +x setup.sh

para rodar a instalação execute o script: ./setup.sh

Exemplo de como preencher as variaveis de setup.
Digite o nome do usuário do banco de dados: glpi_user
Digite a senha do banco de dados: MyStr0ngP@ssw0rd
Digite o nome do domínio do servidor: 10.80.0.139

Todos os logs serão salvos no arquivo "glpi_install_logs" no mesmo diretório em que o script for executado.

ao executar o script de desinstalação apenas comfirme com "sim" e ele fará a desistalação e limpeza de arquico e configurações
