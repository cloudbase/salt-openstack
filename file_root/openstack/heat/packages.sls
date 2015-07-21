{% set heat = salt['openstack_utils.heat']() %}


{% for pkg in heat['packages'] %}
heat_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
