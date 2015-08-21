{% set keystone = salt['openstack_utils.keystone']() %}


{% for pkg in keystone['packages'] %}
keystone_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
