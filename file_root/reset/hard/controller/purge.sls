######################################
###   CONTROLLER NODE HARD RESET   ###
######################################


{% set controller_services = salt['openstack_utils.os_services']('controller') %}
{% for service in controller_services %}
hard_reset_controller_{{ service }}_stopped:
  service.dead:
    - enable: False
    - name: {{ service }}
{% endfor %}


{% set controller_packages = salt['openstack_utils.os_packages']('controller') %}
{% for pkg in controller_packages %}
hard_reset_controller_{{ pkg }}_purged:
  pkg.purged:
    - pkgs:
      - {{ pkg }}
{% endfor %}
