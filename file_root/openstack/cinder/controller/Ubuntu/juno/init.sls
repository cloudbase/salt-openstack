{% set cinder = salt['openstack_utils.cinder']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


cinder_controller_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ cinder['conf']['cinder'] }}"
    - sections:
        keystone_authtoken:
          - auth_host
          - auth_port
          - auth_protocol
    - require:
{% for pkg in cinder['packages']['controller'] %}
      - pkg: cinder_controller_{{ pkg }}_install
{% endfor %}


cinder_controller_conf:
  ini.options_present:
    - name: "{{ cinder['conf']['cinder'] }}"
    - sections:
        DEFAULT:
          my_ip: {{ openstack_parameters['controller_ip'] }}
          auth_strategy: keystone
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
        database:
          connection: "mysql://{{ cinder['database']['username'] }}:{{ cinder['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ cinder['database']['db_name'] }}"
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000/v2.0"
          identity_uri: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          admin_tenant_name: service
          admin_user: cinder
          admin_password: "{{ service_users['cinder']['password'] }}"
    - require:
      - ini: cinder_controller_conf_keystone_authtoken


cinder_db_sync:
  cmd.run:
    - name: "su -s /bin/sh -c 'cinder-manage db sync' cinder"
    - require:
      - ini: cinder_controller_conf


cinder_controller_sqlite_delete:
  file.absent:
    - name: {{ cinder['files']['sqlite'] }}
    - require:
      - cmd: cinder_db_sync


{% for service in cinder['services']['controller'] %}
cinder_controller_{{ service }}_running:
  service.running:
    - enable: True
    - name: {{ cinder['services']['controller'][service] }}
    - watch:
      - ini: cinder_controller_conf
{% endfor %}


cinder_controller_wait:
  cmd.run:
    - name: sleep 5
    - require:
{% for service in cinder['services']['controller'] %}
      - service: cinder_controller_{{ service }}_running
{% endfor %}
