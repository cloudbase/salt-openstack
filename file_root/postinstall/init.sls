{% from "cluster/physical_networks.jinja" import bridges with context %}

{% if grains['os'] == 'CentOS' %}
{% for bridge in bridges %}
{% if bridges[bridge] != None and bridges[bridge] != "" %}
{{ bridges[bridge] }}_promisc_on:
  file:
    - append
    - name: /etc/sysconfig/network-scripts/ifcfg-{{ bridges[bridge] }}
    - text: "PROMISC=yes"
    - unless: cat /etc/sysconfig/network-scripts/ifcfg-{{ bridges[bridge] }} | egrep "PROMISC=yes"
{% endif %}
{% endfor %}
{% endif %}

{% if grains['os'] == 'Ubuntu' %}
{% for bridge in bridges %}
{% if bridges[bridge] != None and bridges[bridge] != "" %}
{{ bridges[bridge] }}_promisc_on:
  file:
    - append
    - name: /etc/rc.local
    - text: "ip link set {{ bridges[bridge] }} up promisc on"
    - unless: cat /etc/rc.local | egrep "ip link set {{ bridges[bridge] }} up promisc on"
{% endif %}
{% endfor %}

rc_local_managed:
  file:
    - managed
    - name: /etc/rc.local
    - user: root
    - group: root
    - mode: 755

automount_cinder_volumes:
  file:
    - append
    - name: /etc/rc.local
    - text: "losetup -f {{ salt['pillar.get']('cinder:volumes_path') }} && vgchange -a y {{ salt['pillar.get']('cinder:volumes_group_name') }} && service {{ salt['pillar.get']('services:cinder_volume') }} restart"
    - unless: "cat /etc/rc.local | egrep 'losetup -f {{ salt['pillar.get']('cinder:volumes_path') }} && vgchange -a y {{ salt['pillar.get']('cinder:volumes_group_name') }} && service {{ salt['pillar.get']('services:cinder_volume') }} restart'"
{% endif %}
