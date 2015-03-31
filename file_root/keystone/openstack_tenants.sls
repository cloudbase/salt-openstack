{% from "cluster/resources.jinja" import get_candidate with context %}

{% for tenant_name in salt['pillar.get']('keystone:tenants') %}
{{ tenant_name }}_tenant:
  keystone:
    - tenant_present
    - name: {{ tenant_name }}
    - connection_token: "{{ salt['pillar.get']('keystone:admin_token') }}"
    - connection_endpoint: "{{ salt['pillar.get']('keystone:services:keystone:endpoint:adminurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}"
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: keystone_reset
{% endif %}
{% endfor %}
{% for role_name in salt['pillar.get']('keystone:roles') %}
{{ role_name }}_role:
  keystone:
    - role_present
    - name: {{ role_name }}
    - connection_token: "{{ salt['pillar.get']('keystone:admin_token') }}"
    - connection_endpoint: "{{ salt['pillar.get']('keystone:services:keystone:endpoint:adminurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}"
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: keystone_reset
{% endif %}
{% endfor %}
