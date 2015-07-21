{% set neutron = salt['openstack_utils.neutron']() %}
{% set openvswitch = salt['openstack_utils.openvswitch']() %}


openvswitch_promisc_interfaces_script:
  file.managed:
    - name: {{ openvswitch['conf']['promisc_interfaces_script'] }}
    - user: root
    - group: root
    - mode: 755
    - contents: |
        #!/usr/bin/env bash
        ip link set br-proxy up promisc on
        ip link set {{ neutron['single_nic']['interface'] }} up promisc on
{% for bridge in neutron['bridges'] %}
  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
        ip link add proxy-veth-{{ bridge }} type veth peer name veth-{{ bridge }}-br-proxy
        ip link set veth-{{ bridge }}-br-proxy up promisc on
        ip link set proxy-veth-{{ bridge }} up promisc on
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


openvswitch_promisc_interfaces_enable:
  service.enabled:
    - name: "{{ salt['openstack_utils.systemd_service_name'])openvswitch['conf']['promisc_interfaces_systemd']) }}"
    - require:
      - file: openvswitch_promisc_interfaces_systemd_service


openvswitch_br-proxy_network_script:
  file.copy:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-br-proxy"
    - source: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-{{ neutron['single_nic']['interface'] }}"
    - unless: "ls {{ openvswitch['conf']['network_scripts'] }}/ifcfg-br-proxy"


openvswitch_{{ neutron['single_nic']['interface'] }}_ovs_port_network_script:
  file.managed:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-{{ neutron['single_nic']['interface'] }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE={{ neutron['single_nic']['interface'] }}
        ONBOOT=yes
        HWADDR={{ grains['hwaddr_interfaces'][neutron['single_nic']['interface']] }}
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE=br-proxy
        ONBOOT=yes
        NOZEROCONF=yes
    - require:
      - file: openvswitch_br-proxy_network_script


{% for bridge in neutron['bridges'] %}
openvswitch_{{ bridge }}_ovs_bridge_network_script:
  file.managed:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-{{ bridge }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE={{ bridge }}
        DEVICETYPE=ovs
        TYPE=OVSBridge
        BOOTPROTO=none
        ONBOOT=yes
        NOZEROCONF=yes


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
    - require:
      - file: openvswitch_{{ bridge }}_ovs_bridge_network_script
  {% endif %}


  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
openvswitch_proxy-veth-{{ bridge }}_ovs_port_network_script:
  file.managed:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-proxy-veth-{{ bridge }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE=proxy-veth-{{ bridge }}
        ONBOOT=yes
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE=br-proxy
        ONBOOT=yes
        NOZEROCONF=yes
    - require:
      - file: openvswitch_br-proxy_network_script
  {% endif %}
{% endfor %}
