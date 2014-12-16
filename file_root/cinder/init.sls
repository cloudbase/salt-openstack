{% from "cluster/resources.jinja" import get_candidate with context %}

cinder_api_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_api', default='cinder-api') }}"

cinder_scheduler_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_scheduler', default='cinder-scheduler') }}"

cinder_conf_file:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:cinder', default='/etc/cinder/cinder.conf') }}"
    - user: cinder
    - group: cinder
    - mode: 644
    - require: 
      - ini: cinder_conf_file
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:cinder', default='/etc/cinder/cinder.conf') }}"
    - sections:
        DEFAULT:
          rpc_backend: "{{ salt['pillar.get']('queue_engine', default='rabbit') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_port: 5672
          rabbit_userid: guest
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
        database:
          connection: "mysql://{{ salt['pillar.get']('databases:cinder:username', default='cinder') }}:{{ salt['pillar.get']('databases:cinder:password', default='cinder_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:cinder:db_name', default='cinder') }}"
        keystone_authtoken:
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: cinder
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:cinder:password') }}"
    - require:
      - pkg: cinder_api_install
      - pkg: cinder_scheduler_install

cinder_sqlite_delete: 
  file: 
    - absent
    - name: /var/lib/cinder/cinder.sqlite
    - require:
      - file: cinder_conf_file

cinder_db_sync:
  cmd:
    - run
    - name: "{{ salt['pillar.get']('databases:cinder:db_sync') }}"
    - require:
      - file: cinder_sqlite_delete

cinder_api_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:cinder_api', default='cinder-api') }}"
    - require:
      - pkg: cinder_scheduler_install
      - pkg: cinder_scheduler_install
    - watch:
      - file: cinder_conf_file
      - ini: cinder_conf_file
      - cmd: cinder_db_sync

cinder_scheduler_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:cinder_scheduler', default='cinder-scheduler') }}"
    - require:
      - pkg: cinder_scheduler_install
      - pkg: cinder_scheduler_install
    - watch:
      - file: cinder_conf_file
      - ini: cinder_conf_file
      - cmd: cinder_db_sync

cinder_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: cinder_api_running
      - service: cinder_scheduler_running
