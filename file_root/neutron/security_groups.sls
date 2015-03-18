{% from "cluster/resources.jinja" import get_candidate with context %}

{% for security_group in salt['pillar.get']('neutron:security_groups', ()) %}
openstack_security_group_{{ security_group }}:
  neutron:
    - security_group_present
    - name: {{ security_group }}
    - description: {{ salt['pillar.get']('neutron:security_groups:%s:description' % security_group, None) }}
    - rules: {{ salt['pillar.get']('neutron:security_groups:%s:rules' % security_group, []) }}
    - connection_user: {{ salt['pillar.get']('neutron:security_groups:%s' % security_group).get('user', 'admin') }}
    - connection_tenant: {{ salt['pillar.get']('neutron:security_groups:%s' % security_group).get('tenant', 'admin') }}
    - connection_password: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:password' % (salt['pillar.get']('neutron:security_groups:%s' % security_group).get('tenant', 'admin'), salt['pillar.get']('neutron:security_groups:%s' % security_group).get('user', 'admin'))) }}
    - connection_auth_url: {{ salt['pillar.get']('keystone:services:keystone:endpoint:internalurl', 'http://{0}:5000/v2.0').format(
    get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: neutron_reset
{% endif %}
{% endfor %}
