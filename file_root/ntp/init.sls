install_ntp:
  pkg:
    - installed
    - refresh: False
    - name: ntp

stop_ntpd:
  service.dead:
    - name: {{ salt['pillar.get']('services:ntp') }}

hwclock_sync:
  cmd.run:
    - name: hwclock --systohc --utc

start_ntp:
  service:
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:ntp') }}
    - require:
      - pkg: ntp
      - cmd: hwclock_sync