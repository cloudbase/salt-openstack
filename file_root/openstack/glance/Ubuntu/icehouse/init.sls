{% set glance = salt['openstack_utils.glance']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


{% for conf in ['api', 'registry'] %}
glance_{{ conf }}_conf:
  ini.options_present:
    - name: "{{ glance['conf'][conf] }}"
    - sections:
        database:
          connection: "mysql://{{ glance['database']['username'] }}:{{ glance['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ glance['database']['db_name'] }}"
        keystone_authtoken:
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_host: "{{ openstack_parameters['controller_ip'] }}"
          auth_port: "35357"
          auth_protocol: http
          admin_tenant_name: service
          admin_user: glance
          admin_password: "{{ service_users['glance']['password'] }}"
        paste_deploy:
          flavor: keystone
        DEFAULT:
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
  {% for pkg in glance['packages'] %}
      - pkg: glance_{{ pkg }}_install
  {% endfor %}
{% endfor %}


glance_db_sync:
  cmd.run:
    - name: "su -s /bin/sh -c 'glance-manage db_sync' glance"
    - require:
      - ini: glance_api_conf
      - ini: glance_registry_conf


glance_registry_running:
  service.running:
    - enable: True
    - name: "{{ glance['services']['registry'] }}"
    - require:
      - cmd: glance_db_sync
    - watch:
      - ini: glance_registry_conf


glance_api_running:
  service.running:
    - enable: True
    - name: "{{ glance['services']['api'] }}"
    - require:
      - cmd: glance_db_sync
    - watch:
      - ini: glance_api_conf


glance_sqlite_delete:
  file.absent:
    - name: "{{ glance['files']['sqlite'] }}"
    - require:
      - cmd: glance_db_sync


glance_wait:
  cmd.run:
    - name: sleep 5
    - require:
      - service: glance_registry_running
      - service: glance_api_running
