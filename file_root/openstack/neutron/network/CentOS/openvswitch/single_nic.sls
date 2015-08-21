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
{% set index = 1 %}
{% for bridge in neutron['bridges'] %}
        ip link set {{ bridge }} up
  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
        ip link add veth-proxy-{{ index }} type veth peer name veth-{{ index }}-proxy
        ip link set veth-{{ index }}-proxy up promisc on
        ip link set veth-proxy-{{ index }} up promisc on
  {% endif %}
  {% set index = index + 1 %}
{% endfor %}
    - require:
{% set index = 1 %}
{% for bridge in neutron['bridges'] %}
  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
      - cmd: openvswitch_veth-proxy-{{ index }}_up
      - cmd: openvswitch_veth-{{ index }}-proxy_up
  {% endif %}
  {% set index = index + 1 %}
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
    - name: "{{ salt['openstack_utils.systemd_service_name'](openvswitch['conf']['promisc_interfaces_systemd']) }}"
    - require:
      - ini: openvswitch_promisc_interfaces_systemd_service


{% set ip_configs = salt['openstack_utils.network_script_ip_configs'](neutron['single_nic']['interface']) %}
openvswitch_br-proxy_network_script:
  ini.options_present:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-br-proxy"
    - unless: "ls {{ openvswitch['conf']['network_scripts'] }}/ifcfg-br-proxy"
    - sections:
        DEFAULT_IMPLICIT:
          DEVICE: br-proxy
          DEVICETYPE: ovs
          TYPE: OVSBridge
{% for config in ip_configs %}
          {{ config }}: "{{ ip_configs[config] }}"
{% endfor %}


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
      - ini: openvswitch_br-proxy_network_script


{% set index = 1 %}
{% for bridge in neutron['bridges'] %}
  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
openvswitch_veth-proxy-{{ index }}_ovs_port_network_script:
  file.managed:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-veth-proxy-{{ index }}"
    - user: root
    - group: root
    - mode: 644
    - contents: |
        DEVICE=veth-proxy-{{ index }}
        ONBOOT=yes
        TYPE=OVSPort
        DEVICETYPE=ovs
        OVS_BRIDGE=br-proxy
        ONBOOT=yes
        NOZEROCONF=yes
    - require:
      - ini: openvswitch_br-proxy_network_script
  {% endif %}
  {% set index = index + 1 %}
{% endfor %}
