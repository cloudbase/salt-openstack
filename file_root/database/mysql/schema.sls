{% set mysql = salt['openstack_utils.mysql']() %}


{% for database in mysql['databases'] %}
mysql_{{ database }}_db:
  mysql_database.present:
    - name: {{ mysql['databases'][database]['db_name'] }}
    - character_set: 'utf8'
    - connection_user: root
    - connection_pass: {{ mysql['root_password'] }}
    - connection_charset: utf8


  {% for host in ['localhost', '%'] %}
mysql_{{ database }}_{{ host }}_account:
  mysql_user.present:
    - name: {{ mysql['databases'][database]['username'] }}
    - password: {{ mysql['databases'][database]['password'] }}
    - host: "{{ host }}"
    - connection_user: root
    - connection_pass: {{ mysql['root_password'] }}
    - connection_charset: utf8
    - require:
      - mysql_database: mysql_{{ database }}_db
  {% endfor %}


  {% for host in ['localhost', '%'] %}
mysql_{{ database }}_{{ host }}_grants:
  mysql_grants.present:
    - grant: all
    - database: "{{ mysql['databases'][database]['db_name'] }}.*"
    - user: {{ mysql['databases'][database]['username'] }}
    - password: {{ mysql['databases'][database]['password'] }}
    - host: "{{ host }}"
    - connection_user: root
    - connection_pass: {{ mysql['root_password'] }}
    - connection_charset: utf8
    - require:
      - mysql_user: mysql_{{ database }}_{{ host }}_account
  {% endfor %}
{% endfor %}
