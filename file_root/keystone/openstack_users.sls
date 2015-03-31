{% from "cluster/resources.jinja" import get_candidate with context %}

{% for tenant_name in salt['pillar.get']('keystone:tenants') %}
{% for user_name in salt['pillar.get']('keystone:tenants:%s:users' % tenant_name) %}
{{ user_name }}_user:
  keystone:
    - user_present
    - name: {{ user_name }}
    - password: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:password' % (tenant_name, user_name)) }}
    - email: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:email' % (tenant_name, user_name)) }}
    - tenant: {{ tenant_name }}
    - roles:
      - {{ tenant_name }}:  {{ salt['pillar.get']('keystone:tenants:%s:users:%s:roles' % (tenant_name, user_name)) }}
    - connection_token: {{ salt['pillar.get']('keystone:admin_token') }}
    - connection_endpoint: "{{ salt['pillar.get']('keystone:services:keystone:endpoint:adminurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}"
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: keystone_reset
{% endif %}
{% endfor %}
{% endfor %}

