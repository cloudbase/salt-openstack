{% set openvswitch = salt['openstack_utils.openvswitch']() %}
{% set neutron = salt['openstack_utils.neutron']() %}


hard_reset_network_openvswitch_promisc_script_delete:
  file.absent:
    - name: "{{ openvswitch['conf']['promisc_interfaces_script'] }}"


hard_reset_network_openvswitch_promisc_service_dead:
  service.dead:
    - enable: False
    - name: "{{ salt['openstack_utils.systemd_service_name'](openvswitch['conf']['promisc_interfaces_systemd']) }}"


hard_reset_network_openvswitch_promisc_systemd_delete:
  file.absent:
    - name: "{{ openvswitch['conf']['promisc_interfaces_systemd'] }}"


{% for bridge in neutron['bridges'] %}
hard_reset_network_openvswitch_{{ bridge }}_ovs_bridge_network_script_delete:
  file.absent:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-{{ bridge }}"


  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
hard_reset_network_openvswitch_proxy-veth-{{ bridge }}_ovs_port_network_script_delete:
  file.absent:
    - name: "{{ openvswitch['conf']['network_scripts'] }}/ifcfg-proxy-veth-{{ bridge }}"
    - require:
      - file: hard_reset_network_openvswitch_{{ bridge }}_ovs_bridge_network_script_delete
  {% endif %}
{% endfor %}