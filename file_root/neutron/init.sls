{% from "cluster/resources.jinja" import get_candidate with context %}

neutron_server_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_server', default='neutron-server') }}"

neutron_conf_file:
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron', default='/etc/neutron/neutron.conf') }}"
    - user: neutron
    - group: neutron
    - mode: 644
    - require: 
      - ini: neutron_conf_file
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron', default='/etc/neutron/neutron.conf') }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          rpc_backend: neutron.openstack.common.rpc.impl_kombu
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          verbose: True
          notify_nova_on_port_status_changes: True
          notify_nova_on_port_data_changes: True
          nova_url: "http://{{ get_candidate('nova') }}:8774/v2"
          nova_admin_username: nova
          nova_admin_tenant_id: service
          nova_admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:nova:password') }}"
          nova_admin_auth_url: "http://{{ get_candidate('keystone') }}:35357/v2.0"
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_protocol: http
          auth_port: 35357
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
        database: 
          connection: "mysql://{{ salt['pillar.get']('databases:neutron:username', default='neutron') }}:{{ salt['pillar.get']('databases:neutron:password', default='neutron_pass') }}@{{ get_candidate('mysql') }}/{{ salt['pillar.get']('databases:neutron:db_name', default='neutron') }}"
    - require: 
      - pkg: neutron_server_install

neutron_server_service_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:neutron_server', default='neutron-server') }}"
    - require: 
      - pkg: neutron_server_install
    - watch: 
      - file: neutron_conf_file
      - ini: neutron_conf_file
      - file: neutron_ml2_conf
      - ini: neutron_ml2_conf

neutron_server_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: neutron_server_service_running
