{% set neutron = salt['openstack_utils.neutron']() %}
{% set keystone = salt['openstack_utils.keystone']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


{% for network in neutron['networks'] %}
neutron_openstack_network_{{ network }}:
  neutron.network_present:
    - name: {{ network }}
    - connection_user: {{ neutron['networks'][network]['user'] }}
    - connection_tenant: {{ neutron['networks'][network]['tenant'] }}
  {% set tenant_users = salt['openstack_utils.openstack_users'](neutron['networks'][network]['tenant']) %}
    - connection_password: {{ tenant_users[neutron['networks'][network]['user']]['password'] }}
    - connection_auth_url: "{{ keystone['openstack_services']['keystone']['endpoint']['adminurl'].format(openstack_parameters['controller_ip']) }}"
  {% for network_param in neutron['networks'][network] %}
    {% if network_param not in ['subnets', 'user', 'tenant'] %}
    - {{ network_param }}: {{ neutron['networks'][network][network_param] }}
    {% endif %}
  {% endfor %}
  {% if salt['openstack_utils.compare_ignore_case'](openstack_parameters['reset'], 'soft') %}
    - require:
      - cmd: neutron_reset
  {% endif %}


  {% set network_subnets = salt['openstack_utils.subnets'](network) %}
  {% for subnet in network_subnets %}
neutron_openstack_subnet_{{ subnet }}:
  neutron.subnet_present:
    - name: {{ subnet }}
    - network: {{ network }}
    - connection_user: {{ neutron['networks'][network]['user'] }}
    - connection_tenant: {{ neutron['networks'][network]['tenant'] }}
    {% set tenant_users = salt['openstack_utils.openstack_users'](neutron['networks'][network]['tenant']) %}
    - connection_password: {{ tenant_users[neutron['networks'][network]['user']]['password'] }}
    - connection_auth_url: "{{ keystone['openstack_services']['keystone']['endpoint']['adminurl'].format(openstack_parameters['controller_ip']) }}"
    {% for subnet_param in network_subnets[subnet] %}
    - {{ subnet_param }}: {{ network_subnets[subnet][subnet_param] }}
    {% endfor %}
    - require:
      - neutron: neutron_openstack_network_{{ network }}
  {% endfor %}
{% endfor %}
