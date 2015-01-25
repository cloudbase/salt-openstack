mysql_client_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:mysql_client') }}

python_mysql_library_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:python_mysql_library') }}
    - require: 
      - pkg: mysql_client_install
