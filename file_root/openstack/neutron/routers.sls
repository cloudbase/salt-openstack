{% set neutron = salt['openstack_utils.neutron']() %}
{% set keystone = salt['openstack_utils.keystone']() %}
{% set openstack_parameters = salt['openstack_utils.openstack_parameters']() %}


{% for router in neutron['routers'] %}
neutron_openstack_router_{{ router }}:
  neutron.router_present:
    - name: {{ router }}
    - interfaces: {{ neutron['routers'][router]['interfaces'] }}
    - gateway_network: {{ neutron['routers'][router]['gateway_network'] }}
    - connection_user: {{ neutron['routers'][router]['user'] }}
    - connection_tenant: {{ neutron['routers'][router]['tenant'] }}
  {% set tenant_users = salt['openstack_utils.openstack_users'](neutron['routers'][router]['tenant']) %}
    - connection_password: {{ tenant_users[neutron['routers'][router]['user']]['password'] }}
    - connection_auth_url: "{{ keystone['openstack_services']['keystone']['endpoint']['internalurl'].format(openstack_parameters['controller_ip']) }}"
  {% if salt['openstack_utils.compare_ignore_case'](openstack_parameters['reset'], 'soft') %}
    - require:
      - cmd: neutron_reset
  {% endif %}
{% endfor %}
