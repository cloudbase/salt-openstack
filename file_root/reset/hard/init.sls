{% set hard_reset_states = salt['openstack_utils.hard_reset_states']() %}


{% if salt['openstack_utils.openstack_series_persist']() %}
  {% if hard_reset_states != [] %}
include:
    {% for state in hard_reset_states %}
  - {{ state }}
    {% endfor %}
  - reset.hard.{{ grains['os'] }}
  {% endif %}


  {% set minion_roles = salt['openstack_utils.minion_roles']() %}
  {% for role in minion_roles %}
    {% set dirs = salt['openstack_utils.minion_packages_dirs'](role) %}
    {% set packages = salt['openstack_utils.os_packages'](role) %}
    {% if packages %}
      {% for dir in dirs %}
hard_reset_{{ role }}_{{ dir }}_absent:
  file.absent:
    - name: {{ dir }}
    - require:
        {% for pkg in packages %}
      - pkg: hard_reset_{{ role }}_{{ pkg }}_purged
        {% endfor %}
      {% endfor %}
    {% endif %}
  {% endfor %}
{% endif %}
