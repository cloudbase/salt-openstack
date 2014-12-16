{% from "cluster/resources.jinja" import get_candidate with context %}

glance_install:
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:glance', default='glance') }}"

python_glanceclient_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:glance_pythonclient', default='python-glanceclient') }}"

glance_api_conf: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:glance_api', default="/etc/glance/glance-api.conf") }}"
    - mode: 644
    - user: glance
    - group: glance
    - require: 
      - ini: glance_api_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:glance_api', default="/etc/glance/glance-api.conf") }}"
    - sections: 
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:glance:username', default='glance') }}:{{ salt['pillar.get']('databases:glance:password', default='glance_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:glance:db_name', default='glance') }}"
        DEFAULT: 
          rpc_backend: "{{ salt['pillar.get']('queue_engine', default='rabbit') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: glance
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:glance:password') }}"
        paste_deploy: 
          flavor: keystone
    - require: 
      - pkg: glance_install
      - pkg: python_glanceclient_install

glance_registry_conf: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:glance_registry', default="/etc/glance/glance-registry.conf") }}"
    - user: glance
    - group: glance
    - mode: 644
    - require: 
      - ini: glance_registry_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:glance_registry', default="/etc/glance/glance-registry.conf") }}"
    - sections: 
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:glance:username', default='glance') }}:{{ salt['pillar.get']('databases:glance:password', default='glance_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:glance:db_name', default='glance') }}"
        DEFAULT: 
          rpc_backend: "{{ salt['pillar.get']('queue_engine', default='rabbit') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
          admin_tenant_name: service
          admin_user: glance
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:glance:password') }}"
        paste_deploy: 
          flavor: keystone
    - require: 
      - pkg: glance_install
      - pkg: python_glanceclient_install

glance_sqlite_delete: 
  file: 
    - absent
    - name: /var/lib/glance/glance.sqlite
    - require: 
      - file: glance_registry_conf
      - file: glance_api_conf

glance_db_sync: 
  cmd: 
    - run
    - name: "{{ salt['pillar.get']('databases:glance:db_sync') }}"
    - require: 
      - file: glance_sqlite_delete

glance_registry_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:glance_registry') }}"
    - require: 
      - pkg: glance_install
      - pkg: python_glanceclient_install
    - watch: 
      - file: glance_api_conf
      - ini: glance_api_conf
      - file: glance_registry_conf
      - ini: glance_registry_conf
      - cmd: glance_db_sync

glance_api_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:glance_api') }}"
    - require: 
      - pkg: glance_install
      - pkg: python_glanceclient_install
    - watch: 
      - file: glance_api_conf
      - ini: glance_api_conf
      - file: glance_registry_conf
      - ini: glance_registry_conf
      - cmd: glance_db_sync

glance_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: glance_registry_running
      - service: glance_api_running
