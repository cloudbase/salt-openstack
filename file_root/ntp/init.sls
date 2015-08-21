{% set ntp = salt['openstack_utils.ntp']() %}


{% for pkg in ntp['packages'] %}
ntp_{{ pkg }}_install:
  pkg.installed:
    - name: {{ pkg }}
{% endfor %}


ntp_service_dead:
  service.dead:
    - name: {{ ntp['services']['ntp'] }}


ntp_hwclock_sync:
  cmd.run:
    - name: hwclock --systohc --utc


ntp_service_running:
  service.running:
    - enable: True
    - name: {{ ntp['services']['ntp'] }}
    - require:
{% for pkg in ntp['packages'] %}
      - pkg: ntp_{{ pkg }}_install
{% endfor %}
      - cmd: ntp_hwclock_sync
