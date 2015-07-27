{% set neutron = salt['openstack_utils.neutron']() %}
{% set openvswitch = salt['openstack_utils.openvswitch']() %}


{% for bridge in neutron['bridges'] %}
  {% if neutron['bridges'][bridge] %}
openvswitch_{{ neutron['bridges'][bridge] }}_ovs_port_network_script:
  file.managed:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-{{ neutron['bridges'][bridge] }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE={{ neutron['bridges'][bridge] }}
        ONBOOT=yes
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE={{ bridge }}
        ONBOOT=yes
        NOZEROCONF=yes
        BOOTPROTO=none
  {% endif %}
{% endfor %}


openvswitch_promisc_interfaces_script:
  file.managed:
    - name: {{ openvswitch['conf']['promisc_interfaces_script'] }}
    - user: root
    - group: root
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
{% for bridge in neutron['bridges'] %}
        ip link set {{ bridge }} up
  {% if neutron['bridges'][bridge] %}
        ip link set {{ neutron['bridges'][bridge] }} up promisc on
  {% endif %}
{% endfor %}
    - require:
{% for bridge in neutron['bridges'] %}
  {% if neutron['bridges'][bridge] %}
      - cmd: openvswitch_interface_{{ bridge }}_{{ neutron['bridges'][bridge] }}_up
  {% endif %}
{% endfor %}


openvswitch_promisc_interfaces_systemd_service:
  ini.options_present:
    - name: {{ openvswitch['conf']['promisc_interfaces_systemd'] }}
    - sections:
        Unit:
          Description: "Set openvswitch ports in promisc mode"
          After: "network.target"
        Service:
          Type: "oneshot"
          ExecStart: "{{ openvswitch['conf']['promisc_interfaces_script'] }}"
        Install:
          WantedBy: "default.target"
    - require:
      - file: openvswitch_promisc_interfaces_script


openstack_promisc_interfaces_enable:
  service.enabled:
    - name: "{{ salt['openstack_utils.systemd_service_name'](openvswitch['conf']['promisc_interfaces_systemd']) }}"
    - require:
      - ini: openvswitch_promisc_interfaces_systemd_service
