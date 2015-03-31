{% from "cluster/resources.jinja" import get_candidate with context %}

{% for router in salt['pillar.get']('neutron:routers', ()) %}
openstack_router_{{ router }}:
  neutron:
    - router_present
    - name: {{ router }}
    - interfaces: {{ salt['pillar.get']('neutron:routers:%s' % router).get('interfaces', 'private_subnet') }}
    - gateway_network: {{ salt['pillar.get']('neutron:routers:%s' % router).get('gateway_network', 'public') }}
    - connection_user: {{ salt['pillar.get']('neutron:routers:%s' % router).get('user', 'admin') }}
    - connection_tenant: {{ salt['pillar.get']('neutron:routers:%s' % router).get('tenant', 'admin') }}
    - connection_password: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:password' % (salt['pillar.get']('neutron:routers:%s' % router).get('tenant', 'admin'), salt['pillar.get']('neutron:routers:%s' % router).get('user', 'admin'))) }}
    - connection_auth_url: {{ salt['pillar.get']('keystone:services:keystone:endpoint:internalurl', 'http://{0}:5000/v2.0').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: neutron_reset
{% endif %}
{% endfor %}
