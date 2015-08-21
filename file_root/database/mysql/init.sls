{% set mysql = salt['openstack_utils.mysql']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


{% for pkg in mysql['packages'] %}
mysql_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}


mysql_conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - name: {{ mysql['conf']['mysqld'] }}
    - contents: |
        [mysqld]
        bind-address = {{ openstack_parameters['controller_ip'] }}
        default-storage-engine = innodb
        innodb_file_per_table
        collation-server = utf8_general_ci
        init-connect = 'SET NAMES utf8'
        character-set-server = utf8
    - require: 
{% for pkg in mysql['packages'] %}
      - pkg: mysql_{{ pkg }}_install
{% endfor %}


mysql_service_running:
  service.running:
    - enable: True
    - name: {{ mysql['services']['mysql'] }}
    - watch: 
      - file: mysql_conf


mysql_secure_installation_script:
  file.managed:
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/mysql-secure-installation.sh"
    - contents: |
        #!/bin/bash
        mysql -u root -p"{{ mysql['root_password'] }}" -e "" &> /dev/null
        if [ $? -eq 0 ]; then
            echo "MySQL root password was already set."
        else
            mysql -u root -e "" &> /dev/null
            if [ $? -eq 0 ]; then
                mysqladmin -u root password "{{ mysql['root_password'] }}"
                echo "MySQL root password has been successfully set."
            else
                echo "ERROR: Cannot change MySQL root password." >&2
                exit 1
            fi
        fi
        mysql -u root -p"{{ mysql['root_password'] }}" -e "UPDATE mysql.user SET Password=PASSWORD('{{ mysql['root_password'] }}') WHERE User='root';"
        mysql -u root -p"{{ mysql['root_password'] }}" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
        mysql -u root -p"{{ mysql['root_password'] }}" -e "DELETE FROM mysql.user WHERE User='';"
        mysql -u root -p"{{ mysql['root_password'] }}" -e "use test;" &> /dev/null
        if [ $? -eq 0 ]; then
            mysql -u root -p"{{ mysql['root_password'] }}" -e "DROP DATABASE test;"
        fi
        mysql -u root -p"{{ mysql['root_password'] }}" -e "FLUSH PRIVILEGES;"
        echo "Finished MySQL secure installation."
        exit 0
    - require:
      - service: mysql_service_running


mysql_secure_installation_run:
  cmd:
    - run
    - name: "bash /tmp/mysql-secure-installation.sh"
    - require:
      - file: mysql_secure_installation_script


mysql_secure_installation_script_delete:
  file:
    - absent
    - name: "/tmp/mysql-secure-installation.sh"
