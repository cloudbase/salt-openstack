{% from "cluster/resources.jinja" import get_candidate with context %}

heat_api_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_api', default='heat_api') }}"

heat_api_cfn_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_api_cfn', default='heat_api_cfn') }}"

heat_engine_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:heat_engine', default='heat_engine') }}"

heat_conf:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:heat', default='/etc/heat/heat.conf') }}"
    - user: heat
    - group: heat
    - mode: 644
    - require: 
      - ini: heat_conf
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:heat', default='/etc/heat/heat.conf') }}"
    - sections: 
        DEFAULT: 
          log_dir: "/var/log/heat"
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          heat_metadata_server_url: http://{{ get_candidate('heat') }}:8000
          heat_waitcondition_server_url: http://{{ get_candidate('heat') }}:8000/v1/waitcondition
        keystone_authtoken: 
          auth_host: "{{ get_candidate('keystone') }}"
          auth_port: 35357
          auth_protocol: http
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
          admin_tenant_name: service
          admin_user: heat
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:heat:password') }}"
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:heat:username', default='heat') }}:{{ salt['pillar.get']('databases:heat:password', default='heat_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:heat:db_name', default='heat') }}"
        ec2authtoken:
          auth_uri: "http://{{ get_candidate('keystone') }}:5000/v2.0"
    - require: 
      - pkg: heat_api_install
      - pkg: heat_api_cfn_install
      - pkg: heat_engine_install

heat_sqlite_delete: 
  file: 
    - absent
    - name: "/var/lib/heat/heat.sqlite"
    - require: 
      - file: heat_conf

heat_db_sync: 
  cmd: 
    - run
    - name: "{{ salt['pillar.get']('databases:heat:db_sync') }}"
    - require: 
      - file: heat_sqlite_delete

heat_api_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:heat_api', default='heat-api') }}"
    - require: 
      - pkg: heat_api_install
    - watch: 
      - file: heat_conf
      - ini: heat_conf
      - cmd: heat_db_sync

heat_api_cfn_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:heat_api_cfn', default='heat-api-cfn') }}"
    - require: 
      - pkg: heat_api_cfn_install
    - watch: 
      - file: heat_conf
      - ini: heat_conf
      - cmd: heat_db_sync

heat_engine_running:
  service:
    - running
    - name: "{{ salt['pillar.get']('services:heat_engine', default='heat-engine') }}"
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
