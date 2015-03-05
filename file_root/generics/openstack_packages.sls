{% if grains['os'] == 'CentOS' %}
openstack_selinux_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:openstack_selinux') }}
    - require:
      - pkg: juno_repo_install

network_manager_dead:
  service:
    - dead
    - name: {{ salt['pillar.get']('services:network_manager') }}
    - enable: False

network_manager_removed:
  pkg:
    - purged
    - name: {{ salt['pillar.get']('services:network_manager') }}
    - require:
      - service: network_manager_dead

network_service_enabled:
  service:
    - enabled
    - name: {{ salt['pillar.get']('services:network') }}
{% endif %}
