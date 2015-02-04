{% from "cluster/resources.jinja" import get_candidate with context %}

heat_api_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_api') }}"

heat_api_cfn_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_api_cfn') }}"

heat_engine_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_engine') }}"

heat_pythonclient_install:
  pkg:
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_pythonclient') }}"

heat_conf:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:heat') }}"
    - user: heat
    - group: heat
    - mode: 644
    - require: 
      - ini: heat_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:heat') }}"
    - sections: 
        DEFAULT: 
{% if grains['os'] == 'Ubuntu' %}
          log_dir: "/var/log/heat"
{% endif %}
{% if pillar['cluster_type'] == 'icehouse' and salt['pillar.get']('queue_engine') == 'rabbit' %}
          rpc_backend: "heat.openstack.common.rpc.impl_kombu"
{% else %}
          rpc_backend: "{{ salt['pillar.get']('queue_engine') }}"
{% endif %}
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password') }}
          heat_metadata_server_url: http://{{ get_candidate('heat') }}:8000
          heat_waitcondition_server_url: http://{{ get_candidate('heat') }}:8000/v1/waitcondition
        keystone_authtoken: 
{% if pillar['cluster_type'] == 'juno' %}
          identity_uri: http://{{ get_candidate('keystone') }}:35357
{% else %}
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
{% endif %}
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          admin_tenant_name: service
          admin_user: heat
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:heat:password') }}"
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:heat:username') }}:{{ salt['pillar.get']('databases:heat:password') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:heat:db_name') }}"
        ec2authtoken:
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
    - require: 
      - pkg: heat_api_install
      - pkg: heat_api_cfn_install
      - pkg: heat_engine_install
      - pkg: heat_pythonclient_install

heat_sqlite_delete: 
  file: 
    - absent
    - name: "/var/lib/heat/heat.sqlite"
    - require: 
      - file: heat_conf

heat_db_sync: 
  cmd: 
    - run
    - name: "su -s /bin/sh -c 'heat-manage db_sync' heat"
    - require: 
      - file: heat_sqlite_delete

heat_api_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:heat_api') }}"
    - require: 
      - pkg: heat_api_install
    - watch: 
      - file: heat_conf
      - ini: heat_conf
      - cmd: heat_db_sync

heat_api_cfn_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:heat_api_cfn') }}"
    - require: 
      - pkg: heat_api_cfn_install
    - watch: 
      - file: heat_conf
      - ini: heat_conf
      - cmd: heat_db_sync

heat_engine_running:
  service:
    - running
    - enable: True
    - name: "{{ salt['pillar.get']('services:heat_engine') }}"
    - require: 
      - pkg: heat_engine_install
    - watch: 
      - file: heat_conf
      - ini: heat_conf
      - cmd: heat_db_sync

heat_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: heat_api_running
      - service: heat_api_cfn_running
      - service: heat_engine_running
