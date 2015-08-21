{% set cinder = salt['openstack_utils.cinder']() %}


{% for pkg in cinder['packages']['controller'] %}
cinder_controller_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
