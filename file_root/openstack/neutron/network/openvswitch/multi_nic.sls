{% set neutron = salt['openstack_utils.neutron']() %}


{% for bridge in neutron['bridges'] %}
openvswitch_bridge_{{ bridge }}_create:
  cmd.run:
    - name: "ovs-vsctl add-br {{ bridge }}"
    - unless: "ovs-vsctl br-exists {{ bridge }}"


openvswitch_bridge_{{ bridge }}_up:
  cmd.run:
    - name: "ip link set {{ bridge }} up"
    - require:
      - cmd: openvswitch_bridge_{{ bridge }}_create


  {% if neutron['bridges'][bridge] %}
openvswitch_interface_{{ bridge }}_{{ neutron['bridges'][bridge] }}_add:
  cmd.run:
    - name: "ovs-vsctl add-port {{ bridge }} {{ neutron['bridges'][bridge] }}"
    - unless: "ovs-vsctl list-ports {{ bridge }} | grep {{ neutron['bridges'][bridge] }}"
    - require: 
      - cmd: openvswitch_bridge_{{ bridge }}_up


openvswitch_interface_{{ bridge }}_{{ neutron['bridges'][bridge] }}_up:
  cmd.run:
    - name: "ip link set {{ neutron['bridges'][bridge] }} up promisc on"
    - require:
      - cmd: openvswitch_interface_{{ bridge }}_{{ neutron['bridges'][bridge] }}_add
  {% endif %}
{% endfor %}
