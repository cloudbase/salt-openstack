{% from "cluster/resources.jinja" import get_candidate with context %}

{% for network in salt['pillar.get']('neutron:networks', ()) %}
openstack_network_{{ network }}:
  neutron:
    - network_present
    - name: {{ network }}
    - connection_user: {{ salt['pillar.get']('neutron:networks:%s' % network).get('user', 'admin') }}
    - connection_tenant: {{ salt['pillar.get']('neutron:networks:%s' % network).get('tenant', 'admin') }}
    - connection_password: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:password' % (salt['pillar.get']('neutron:networks:%s' % network).get('tenant', 'admin'), salt['pillar.get']('neutron:networks:%s' % network).get('user', 'admin'))) }}
    - connection_auth_url: {{ salt['pillar.get']('keystone:services:keystone:endpoint:internalurl', 'http://{0}:5000/v2.0').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
{% for network_param in salt['pillar.get']('neutron:networks:%s' % network, ()) %}
{% if network_param not in ('subnets', 'user', 'tenant') %}
    - {{ network_param }}: {{ salt['pillar.get']('neutron:networks:%s' % network)[network_param] }}
{% endif %}
{% endfor %}
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: neutron_reset
{% endif %}
{% for subnet in salt['pillar.get']('neutron:networks:%s:subnets' % network, ()) %}
openstack_subnet_{{ subnet }}:
  neutron:
    - subnet_present
    - name: {{ subnet }}
    - network: {{ network }}
    - connection_user: {{ salt['pillar.get']('neutron:networks:%s' % network).get('user', 'admin') }}
    - connection_tenant: {{ salt['pillar.get']('neutron:networks:%s' % network).get('tenant', 'admin') }}
    - connection_password: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:password' % (salt['pillar.get']('neutron:networks:%s' % network).get('tenant', 'admin'), salt['pillar.get']('neutron:networks:%s' % network).get('user', 'admin'))) }}
    - connection_auth_url: {{ salt['pillar.get']('keystone:services:keystone:endpoint:internalurl', 'http://{0}:5000/v2.0').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
{% for subnet_param in salt['pillar.get']('neutron:networks:%s:subnets:%s' % (network, subnet), ()) %}
    - {{ subnet_param }}: {{ salt['pillar.get']('neutron:networks:%s' % network)['subnets'][subnet][subnet_param] }}
{% endfor %}
    - require:
      - neutron: openstack_network_{{ network }}
{% endfor %}
{% endfor %}
