{% set keystone = salt['openstack_utils.keystone']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}

{% for tenant_name in keystone['openstack_tenants'] %}
  {% set tenant_users = salt['openstack_utils.openstack_users'](tenant_name) %}
  {% for user in tenant_users %}
keystone_{{ user }}_user:
  keystone:
    - user_present
    - name: {{ user }}
    - password: {{ tenant_users[user]['password'] }}
    - email: {{ tenant_users[user]['email'] }}
    - tenant: {{ tenant_name }}
    - roles:
      - {{ tenant_name }}: {{ tenant_users[user]['roles'] }}
    - connection_token: "{{ keystone['admin_token'] }}"
    - connection_endpoint: "{{ keystone['openstack_services']['keystone']['endpoint']['adminurl'].format(openstack_parameters['controller_ip']) }}"
    {% if salt['openstack_utils.compare_ignore_case'](openstack_parameters['reset'], 'soft') %}
    - require:
      - cmd: keystone_reset
    {% endif %}

    {% if tenant_users[user].has_key('keystonerc') and
          tenant_users[user]['keystonerc'].has_key('create') and
          salt['openstack_utils.boolean_value'](tenant_users[user]['keystonerc']['create']) %}
keystonerc_{{ user }}_create:
  file.managed:
    - name: {{ tenant_users[user]['keystonerc']['path'] }}
    - contents: |
        export OS_USERNAME={{ user }}
        export OS_PROJECT_NAME={{ tenant_name }}
        export OS_TENANT_NAME={{ tenant_name }}
        export OS_PASSWORD={{ tenant_users[user]['password'] }}
        export OS_AUTH_URL={{ keystone['openstack_services']['keystone']['endpoint']['publicurl'].format(openstack_parameters['controller_ip']) }}
        export OS_VOLUME_API_VERSION=2
        export OS_IMAGE_API_VERSION=2
        export PS1='[\u@\h \W(keystonerc_{{ user }})]\$ '
    - require:
      - keystone: keystone_{{ user }}_user
    {% endif %}
  {% endfor %}
{% endfor %}
