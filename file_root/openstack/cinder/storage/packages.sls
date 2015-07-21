{% set cinder = salt['openstack_utils.cinder']() %}


{% for pkg in cinder['packages']['storage'] %}
cinder_storage_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
