{% for openstack_service in salt['pillar.get']('databases') %}
{{ openstack_service }}_db:
  mysql_database:
    - present
    - name: {{ salt['pillar.get']('databases:%s:db_name' % openstack_service) }}
    - character_set: 'utf8'
    - connection_user: root
    - connection_pass: {{ salt['pillar.get']('mysql:root_password', default='Passw0rd') }}
    - connection_charset: utf8

localhost_{{ openstack_service }}_account:
  mysql_user:
    - present
    - name: {{ salt['pillar.get']('databases:%s:username' % openstack_service) }}
    - password: {{ salt['pillar.get']('databases:%s:password' % openstack_service) }}
    - host: "localhost"
    - connection_user: root
    - connection_pass: {{ salt['pillar.get']('mysql:root_password', default='Passw0rd') }}
    - connection_charset: utf8
    - require:
      - mysql_database: {{ openstack_service }}_db
  mysql_grants:
    - present
    - grant: all
    - database: "{{ salt['pillar.get']('databases:%s:db_name' % openstack_service) }}.*"
    - user: {{ salt['pillar.get']('databases:%s:username' % openstack_service) }}
    - password: {{ salt['pillar.get']('databases:%s:password' % openstack_service) }}
    - host: "localhost"
    - connection_user: root
    - connection_pass: {{ salt['pillar.get']('mysql:root_password', default='Passw0rd') }}
    - connection_charset: utf8
    - require:
      - mysql_user: localhost_{{ openstack_service }}_account

other_hosts_{{ openstack_service }}_account:
  mysql_user:
    - present
    - name: {{ salt['pillar.get']('databases:%s:username' % openstack_service) }}
    - password: {{ salt['pillar.get']('databases:%s:password' % openstack_service) }}
    - host: "%"
    - connection_user: root
    - connection_pass: {{ salt['pillar.get']('mysql:root_password', default='Passw0rd') }}
    - connection_charset: utf8
    - require:
      - mysql_database: {{ openstack_service }}_db
  mysql_grants:
    - present
    - grant: all
    - database: "{{ salt['pillar.get']('databases:%s:db_name' % openstack_service) }}.*"
    - user: {{ salt['pillar.get']('databases:%s:username' % openstack_service) }}
    - password: {{ salt['pillar.get']('databases:%s:password' % openstack_service) }}
    - host: "%"
    - connection_user: root
    - connection_pass: {{ salt['pillar.get']('mysql:root_password', default='Passw0rd') }}
    - connection_charset: utf8
    - require:
      - mysql_user: other_hosts_{{ openstack_service }}_account

{% endfor %}
