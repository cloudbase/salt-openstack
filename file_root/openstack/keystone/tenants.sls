{% set keystone = salt['openstack_utils.keystone']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}

{% for tenant_name in keystone['openstack_tenants'] %}
keystone_{{ tenant_name }}_tenant:
  keystone:
    - tenant_present
    - name: {{ tenant_name }}
    - connection_token: "{{ keystone['admin_token'] }}"
    - connection_endpoint: "{{ keystone['openstack_services']['keystone']['endpoint']['adminurl'].format(openstack_parameters['controller_ip']) }}"
  {% if salt['openstack_utils.compare_ignore_case'](openstack_parameters['reset'], 'soft') %}
    - require:
      - cmd: keystone_reset
  {% endif %}
{% endfor %}

{% for role_name in keystone['openstack_roles'] %}
keystone_{{ role_name }}_role:
  keystone:
    - role_present
    - name: {{ role_name }}
    - connection_token: "{{ keystone['admin_token'] }}"
    - connection_endpoint: "{{ keystone['openstack_services']['keystone']['endpoint']['adminurl'].format(openstack_parameters['controller_ip']) }}"
  {% if salt['openstack_utils.compare_ignore_case'](openstack_parameters['reset'], 'soft') %}
    - require:
      - cmd: keystone_reset
  {% endif %}
{% endfor %}
