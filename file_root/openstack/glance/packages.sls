{% set glance = salt['openstack_utils.glance']() %}


{% for pkg in glance['packages'] %}
glance_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
