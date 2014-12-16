{% from "cluster/resources.jinja" import get_candidate with context %}

keystone_install: 
  pkg: 
    - installed
    - name: {{ salt['pillar.get']('packages:keystone', default='keystone') }}

keystone_conf:
    file: 
      - managed
      - name: {{ salt['pillar.get']('conf_files:keystone', default='/etc/keystone/keystone.conf') }}
      - user: root
      - group: root
      - mode: 644
      - require: 
        - ini: keystone_conf
    ini: 
      - options_present
      - name: {{ salt['pillar.get']('conf_files:keystone', default='/etc/keystone/keystone.conf') }}
      - sections: 
          DEFAULT: 
            log_dir: "/var/log/keystone"
            admin_token: {{ salt['pillar.get']('keystone:admin_token', default='ADMIN') }}
          database: 
            connection: mysql://{{ salt['pillar.get']('databases:keystone:username', default='keystone') }}:{{ salt['pillar.get']('databases:keystone:password', default='keystone_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:keystone:db_name', default='keystone') }}
      - require: 
        - pkg: keystone_install

keystone_sqlite_delete: 
  file: 
    - absent
    - name: /var/lib/keystone/keystone.sqlite
    - require: 
      - file: keystone_conf

keystone_db_sync: 
  cmd: 
    - run
    - name: {{ salt['pillar.get']('databases:keystone:db_sync') }}
    - require: 
      - file: keystone_sqlite_delete

keystone_service_running:
  service: 
    - running
    - name: {{ salt['pillar.get']('services:keystone', default='keystone') }}
    - require: 
      - pkg: keystone_install
    - watch: 
      - file: keystone_conf
      - ini: keystone_conf
      - cmd: keystone_db_sync

keystone_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: keystone_service_running
