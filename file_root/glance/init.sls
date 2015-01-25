{% from "cluster/resources.jinja" import get_candidate with context %}

glance_install:
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:glance') }}"

python_glanceclient_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:glance_pythonclient') }}"

glance_api_conf: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:glance_api') }}"
    - mode: 644
    - user: glance
    - group: glance
    - require: 
      - ini: glance_api_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:glance_api') }}"
    - sections: 
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:glance:username') }}:{{ salt['pillar.get']('databases:glance:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:glance:db_name') }}"
        DEFAULT: 
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
        keystone_authtoken: 
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: "http://{{ get_candidate('keystone') }}:35357"
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
{% endif %}
          admin_tenant_name: service
          admin_user: glance
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:glance:password') }}"
{% if pillar['cluster_type'] == 'juno' %}
        glance_store:
          default_store: file
          filesystem_store_datadir: "/var/lib/glance/images/"
{% endif %}
        paste_deploy: 
          flavor: keystone
    - require: 
      - pkg: glance_install
      - pkg: python_glanceclient_install

glance_registry_conf: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:glance_registry') }}"
    - user: glance
    - group: glance
    - mode: 644
    - require: 
      - ini: glance_registry_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:glance_registry') }}"
    - sections: 
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:glance:username') }}:{{ salt['pillar.get']('databases:glance:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:glance:db_name') }}"
        DEFAULT: 
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
        keystone_authtoken: 
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: "http://{{ get_candidate('keystone') }}:35357"
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
{% endif %}
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
    - name: "su -s /bin/sh -c 'glance-manage db_sync' glance"
    - require: 
      - file: glance_sqlite_delete

glance_registry_running:
  service: 
    - running
    - enable: True
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
    - enable: True
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
