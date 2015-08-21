{% set horizon = salt['openstack_utils.horizon']() %}


{% for pkg in horizon['packages'] %}
horizon_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
