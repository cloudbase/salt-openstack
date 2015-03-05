mysql_server_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:mysql_server') }}

mysql_conf:
  file: 
    - managed
    - group: root
    - mode: 644
    - name: {{ salt['pillar.get']('conf_files:mysql') }}
    - user: root
    - require: 
      - ini: mysql_conf
  ini: 
    - options_present
    - name: {{ salt['pillar.get']('conf_files:mysql') }}
    - sections: 
        mysqld: 
          bind-address: 0.0.0.0
          default-storage-engine: InnoDB
          collation-server: utf8_general_ci
          init-connect: "'SET NAMES utf8'"
          character-set-server: utf8
    - require: 
      - pkg: mysql_server_install

mysql_service_running:
  service: 
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:mysql') }}
    - require:
      - pkg: mysql_server_install
    - watch: 
      - file: mysql_conf
      - ini: mysql_conf

{% set root_password = salt['pillar.get']('mysql:root_password') %}
mysql_secure_installation_script:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/mysql-secure-installation.sh"
    - contents: |
        #!/bin/bash
        mysql -u root -p"{{ root_password }}" -e "" &> /dev/null
        if [ $? -eq 0 ]; then
            echo "MySQL root password was already set."
        else
            mysql -u root -e "" &> /dev/null
            if [ $? -eq 0 ]; then
                mysqladmin -u root password "{{ root_password }}"
                echo "MySQL root password has been successfully set."
            else
                echo "ERROR: Cannot change MySQL root password." >&2
                exit 1
            fi
        fi
        mysql -u root -p"{{ root_password }}" -e "UPDATE mysql.user SET Password=PASSWORD('{{ root_password }}') WHERE User='root';"
        mysql -u root -p"{{ root_password }}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        mysql -u root -p"{{ root_password }}" -e "DELETE FROM mysql.user WHERE User='';"
        mysql -u root -p"{{ root_password }}" -e "use test;" &> /dev/null
        if [ $? -eq 0 ]; then
            mysql -u root -p"{{ root_password }}" -e "DROP DATABASE test;"
        fi
        mysql -u root -p"{{ root_password }}" -e "FLUSH PRIVILEGES;"
        echo "Finished MySQL secure installation."
        exit 0
    - require:
      - service: mysql_service_running

mysql_secure_installation:
  cmd:
    - run
    - name: "bash /tmp/mysql-secure-installation.sh"
    - require:
      - file: mysql_secure_installation_script

mysql_secure_installation_script_delete:
  file:
    - absent
    - name: "/tmp/mysql-secure-installation.sh"
