{% from "cluster/resources.jinja" import get_candidate with context %}

{% for service_name in salt['pillar.get']('keystone:services') %}
{{ service_name }}_service:
  keystone:
    - service_present
    - name: {{ service_name }}
    - service_type: {{ salt['pillar.get']('keystone:services:%s:service_type' % service_name) }}
    - description: {{ salt['pillar.get']('keystone:services:%s:description' % service_name) }}
    - connection_token: {{ salt['pillar.get']('keystone:admin_token') }}
    - connection_endpoint: {{ salt['pillar.get']('keystone:services:keystone:endpoint:adminurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: keystone_reset
{% endif %}

{{ service_name }}_endpoint:
  keystone:
    - endpoint_present
    - name: {{ service_name }}
    - publicurl: {{ salt['pillar.get']('keystone:services:%s:endpoint:publicurl' % service_name).format(get_candidate(salt['pillar.get']('keystone:services:%s:endpoint:endpoint_host_sls' % service_name))) }}
    - adminurl: {{ salt['pillar.get']('keystone:services:%s:endpoint:adminurl' % service_name).format(get_candidate(salt['pillar.get']('keystone:services:%s:endpoint:endpoint_host_sls' % service_name))) }}
    - internalurl: {{ salt['pillar.get']('keystone:services:%s:endpoint:internalurl' % service_name).format(get_candidate(salt['pillar.get']('keystone:services:%s:endpoint:endpoint_host_sls' % service_name))) }}
    - region: "RegionOne"
    - connection_token: {{ salt['pillar.get']('keystone:admin_token') }}
    - connection_endpoint: {{ salt['pillar.get']('keystone:services:keystone:endpoint:adminurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
    - require:
      - keystone: {{ service_name }}_service
{% endfor %}
