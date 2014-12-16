mysql_client_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:mysql_client', default='mysql-client') }}

python_mysql_library_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:python_mysql_library', default='python-mysqldb') }}
    - require: 
      - pkg: mysql_client_install
