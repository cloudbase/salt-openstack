{% set nova = salt['openstack_utils.nova']() %}


{% for pkg in nova['packages']['compute']['kvm'] %}
nova_compute_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}
