mysql_server_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:mysql_server', default='mysql-server') }}

mysql_conf:
  file: 
    - managed
    - group: root
    - mode: 644
    - name: {{ salt['pillar.get']('conf_files:mysql', default='/etc/mysql/my.cnf') }}
    - user: root
    - require: 
      - ini: mysql_conf
  ini: 
    - options_present
    - name: {{ salt['pillar.get']('conf_files:mysql', default='/etc/mysql/my.cnf') }}
    - sections: 
        mysqld: 
          bind-address: 0.0.0.0
          character-set-server: utf8
          collation-server: utf8_general_ci
          init-connect: 'SET NAMES utf8'
    - require: 
      - pkg: mysql_server_install

mysql_service_running:
  service: 
    - running
    - name: {{ salt['pillar.get']('services:mysql', default='mysql') }}
    - require:
      - pkg: mysql_server_install
    - watch: 
      - file: mysql_conf
      - ini: mysql_conf

root_password_set:
  cmd:
    - run
    - name: mysqladmin -u root password {{ salt['pillar.get']('mysql:root_password', default='Passw0rd') }}
    - require:
      - service: mysql_service_running
