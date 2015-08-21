{% set heat = salt['openstack_utils.heat']() %}
{% set service_users = salt['openstack_utils.openstack_users']('service') %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}
{% set keystone = salt['openstack_utils.keystone']() %}
{% set admin_users = salt['openstack_utils.openstack_users']('admin') %}


heat_conf_create:
  file.copy:
    - name: "{{ heat['conf']['heat'] }}"
    - source: "{{ heat['conf']['heat_conf_dist'] }}"
    - user: heat
    - group: heat
    - require:
{% for pkg in heat['packages'] %}
      - pkg: heat_{{ pkg }}_install
{% endfor %}


heat_conf:
  ini.options_present:
    - name: "{{ heat['conf']['heat'] }}"
    - sections:
        database:
          connection: "mysql://{{ heat['database']['username'] }}:{{ heat['database']['password'] }}@{{ openstack_parameters['controller_ip'] }}/{{ heat['database']['db_name'] }}"
        DEFAULT:
          heat_metadata_server_url: "http://{{ openstack_parameters['controller_ip'] }}:8000"
          heat_waitcondition_server_url: "http://{{ openstack_parameters['controller_ip'] }}:8000/v1/waitcondition"
          stack_domain_admin: heat_domain_admin
          stack_domain_admin_password: {{ service_users['heat']['password'] }}
          stack_user_domain_name: heat_user_domain
          debug: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
          verbose: "{{ salt['openstack_utils.boolean_value'](openstack_parameters['debug_mode']) }}"
        keystone_authtoken:
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000/v2.0"
          identity_uri: "http://{{ openstack_parameters['controller_ip'] }}:35357"
          admin_tenant_name: service
          admin_user: heat
          admin_password: {{ service_users['heat']['password'] }}
        ec2authtoken:
          auth_uri: "http://{{ openstack_parameters['controller_ip'] }}:5000/v2.0"
    - require:
{% for pkg in heat['packages'] %}
      - pkg: heat_{{ pkg }}_install
{% endfor %}


heat_domain_create:
  cmd.run:
    - name: |
        export OS_USERNAME=admin && \
        export OS_TENANT_NAME=admin && \
        export OS_PASSWORD={{ admin_users['admin']['password'] }} && \
        export OS_AUTH_URL={{ keystone['openstack_services']['keystone']['endpoint']['adminurl'].format(openstack_parameters['controller_ip']) }} && \
        heat-keystone-setup-domain \
          --stack-user-domain-name heat_user_domain \
          --stack-domain-admin heat_domain_admin \
          --stack-domain-admin-password {{ service_users['heat']['password'] }}
    - require:
      - ini: heat_conf


heat_db_sync:
  cmd.run:
    - name: "su -s /bin/sh -c 'heat-manage db_sync' heat"
    - require: 
      - cmd: heat_domain_create


heat_sqlite_delete:
  file.absent:
    - name: "{{ heat['files']['sqlite'] }}"
    - require:
      - cmd: heat_db_sync


{% for service in heat['services'] %}
heat_service_{{ service }}_running:
  service.running:
    - name: {{ heat['services'][service] }}
    - enable: True
    - require:
      - cmd: heat_db_sync
    - watch:
      - ini: heat_conf
{% endfor %}


heat_wait:
  cmd.run:
    - name: sleep 5
    - require:
{% for service in heat['services'] %}
      - service: heat_service_{{ service }}_running
{% endfor %}
