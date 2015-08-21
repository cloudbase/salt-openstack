####################################
###    NETWORK NODE HARD RESET   ###
####################################


{% set network_services = salt['openstack_utils.os_services']('network') %}
{% for service in network_services %}
hard_reset_network_{{ service }}_stopped:
  service.dead:
    - enable: False
    - name: {{ service }}
{% endfor %}


{% set network_packages = salt['openstack_utils.os_packages']('network') %}
{% for pkg in network_packages %}
hard_reset_network_{{ pkg }}_purged:
  pkg.purged:
    - pkgs:
      - {{ pkg }}
{% endfor %}
