{% from "cluster/physical_networks.jinja" import bridges with context %}

rc_local_commands:
  file:
    - managed
    - name: "/etc/rc.local"
    - group: root
    - user: root
    - mode: 755
    - contents: |
        #!/bin/sh -e
{% for bridge in bridges %}
{% if bridges[bridge] != None %}
        ip link set {{ bridges[bridge] }} up promisc on
{% endif %}
{% endfor %}
        losetup -f {{ salt['pillar.get']('cinder:volumes_path', default='/var/lib/cinder/cinder-volumes') }} && vgchange -a y {{ salt['pillar.get']('cinder:volumes_group_name', default='cinder-volumes') }} && service {{ salt['pillar.get']('services:cinder_volume', default='cinder-volume') }} restart
        exit 0
