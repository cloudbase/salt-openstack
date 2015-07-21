{% set nova = salt['openstack_utils.nova']() %}


{% for pkg in nova['packages']['controller'] %}
nova_controller_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
