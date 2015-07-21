{% set glance = salt['openstack_utils.glance']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


glance_api_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ glance['conf']['api'] }}"
    - sections:
      - keystone_authtoken
    - require:
{% for pkg in glance['packages'] %}
      - pkg: glance_{{ pkg }}_install
{% endfor %}


glance_api_conf:
  ini.options_present:
    - name: "{{ glance['conf']['api'] }}"
    - sections: 
        database: 
          connection: "mysql://{{ glance['database']['username'] }}:{{ glance['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ glance['database']['db_name'] }}"
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_plugin: "password"
          project_domain_id: "default"
          user_domain_id: "default"
          project_name: "service"
          username: "glance"
          password: "{{ service_users['glance']['password'] }}"
        paste_deploy: 
          flavor: keystone
        glance_store:
          default_store: file
          filesystem_store_datadir: {{ glance['files']['images_dir'] }}
        DEFAULT:
          notification_driver: noop
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
      - ini: glance_api_conf_keystone_authtoken


glance_registry_conf_keystone_authtoken:
  ini.sections_absent:
    - name: "{{ glance['conf']['registry'] }}"
    - sections:
      - keystone_authtoken
    - require:
{% for pkg in glance['packages'] %}
      - pkg: glance_{{ pkg }}_install
{% endfor %}


glance_registry_conf:
  ini.options_present:
    - name: "{{ glance['conf']['registry'] }}"
    - sections:
        database:
          connection: "mysql://{{ glance['database']['username'] }}:{{ glance['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ glance['database']['db_name'] }}"
        keystone_authtoken: 
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000"
          auth_url: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          auth_plugin: "password"
          project_domain_id: "default"
          user_domain_id: "default"
          project_name: "service"
          username: "glance"
          password: "{{ service_users['glance']['password'] }}"
        paste_deploy: 
          flavor: keystone
        DEFAULT:
          notification_driver: noop
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
    - require:
      - ini: glance_registry_conf_keystone_authtoken


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
