{% from "cluster/resources.jinja" import get_candidate with context %}

{% if grains['os'] == 'Ubuntu' %}
cinder_api_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_api') }}"

cinder_scheduler_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_scheduler') }}"
{% elif grains['os'] == 'CentOS' %}
cinder_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_volume') }}"

olso_db_python_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:olso_db_python') }}"
{% endif %}

cinder_pythonclient_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:cinder_pythonclient') }}"

cinder_conf_file:
  file:
    - managed
    - name: "{{ salt['pillar.get']('conf_files:cinder') }}"
    - user: cinder
    - group: cinder
    - mode: 644
    - require: 
      - ini: cinder_conf_file
  ini:
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:cinder') }}"
    - sections:
        DEFAULT:
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_port: 5672
          rabbit_userid: guest
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
{% if pillar['cluster_type'] == 'juno' %}
          my_ip: {{ get_candidate('cinder') }}
{% endif %}
        database:
          connection: "mysql://{{ salt['pillar.get']('databases:cinder:username') }}:{{ salt['pillar.get']('databases:cinder:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:cinder:db_name') }}"
        keystone_authtoken:
{% if pillar['cluster_type'] == 'juno' %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
{% endif %}
          admin_tenant_name: service
          admin_user: cinder
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:cinder:password') }}"
    - require:
{% if grains['os'] == 'Ubuntu' %}
      - pkg: cinder_api_install
      - pkg: cinder_scheduler_install
{% elif grains['os'] == 'CentOS' %}
      - pkg: cinder_install
      - pkg: olso_db_python_install
{% endif %}
      - pkg: cinder_pythonclient_install

cinder_sqlite_delete: 
  file: 
    - absent
    - name: /var/lib/cinder/cinder.sqlite
    - require:
      - file: cinder_conf_file

cinder_db_sync:
  cmd:
    - run
    - name: "su -s /bin/sh -c 'cinder-manage db sync' cinder"
    - require:
      - file: cinder_sqlite_delete

cinder_api_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:cinder_api') }}"
    - require:
{% if grains['os'] == 'Ubuntu' %}
      - pkg: cinder_api_install
      - pkg: cinder_scheduler_install
{% elif grains['os'] == 'CentOS' %}
      - pkg: cinder_install
      - pkg: olso_db_python_install
{% endif %}
      - pkg: cinder_pythonclient_install
    - watch:
      - file: cinder_conf_file
      - ini: cinder_conf_file
      - cmd: cinder_db_sync

cinder_scheduler_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:cinder_scheduler') }}"
    - require:
{% if grains['os'] == 'Ubuntu' %}
      - pkg: cinder_api_install
      - pkg: cinder_scheduler_install
{% elif grains['os'] == 'CentOS' %}
      - pkg: cinder_install
      - pkg: olso_db_python_install
{% endif %}
      - pkg: cinder_pythonclient_install
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
