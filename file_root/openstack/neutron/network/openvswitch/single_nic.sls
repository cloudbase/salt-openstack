{% set neutron = salt['openstack_utils.neutron']() %}


openvswitch_bridge_br-proxy_create:
  cmd.run:
    - name: "ovs-vsctl add-br br-proxy"
    - unless: "ovs-vsctl br-exists br-proxy"


openvswitch_bridge_br-proxy_up:
  cmd.run:
    - name: "ip link set br-proxy promisc on"
    - require: 
      - cmd: openvswitch_bridge_br-proxy_create


openvswitch_{{ neutron['single_nic']['interface'] }}_up:
  cmd.run:
    - name: "ip link set {{ neutron['single_nic']['interface'] }} promisc on"
    - require:
      - cmd: openvswitch_bridge_br-proxy_up


{% for bridge in neutron['bridges'] %}
openvswitch_bridge_{{ bridge }}_create:
  cmd.run:
    - name: "ovs-vsctl add-br {{ bridge }}"
    - unless: "ovs-vsctl br-exists {{ bridge }}"
    - require:
      - cmd: openvswitch_{{ neutron['single_nic']['interface'] }}_up


openvswitch_bridge_{{ bridge }}_up:
  cmd.run:
    - name: "ip link set {{ bridge }} up"
    - require:
      - cmd: openvswitch_bridge_{{ bridge }}_create


  {% if bridge not in [ neutron['tunneling']['bridge'], neutron['integration_bridge'] ] %}
openvswitch_veth_{{ bridge }}_create:
  cmd.run:
    - name: "ip link add proxy-veth-{{ bridge }} type veth peer name veth-{{ bridge }}-br-proxy"
    - unless: "ip link list | egrep proxy-veth-{{ bridge }}"
    - require:
      - cmd: openvswitch_bridge_{{ bridge }}_up


openvswitch_veth-{{ bridge }}-br-proxy_add:
  cmd.run:
    - name: "ovs-vsctl add-port {{ bridge }} veth-{{ bridge }}-br-proxy"
    - unless: "ovs-vsctl list-ports {{ bridge }} | grep veth-{{ bridge }}-br-proxy"
    - require:
      - cmd: openvswitch_veth_{{ bridge }}_create


openvswitch_veth-{{ bridge }}-br-proxy_up:
  cmd.run:
    - name: "ip link set veth-{{ bridge }}-br-proxy up promisc on"
    - require:
      - cmd: openvswitch_veth-{{ bridge }}-br-proxy_add


openvswitch_proxy-veth-{{ bridge }}_add:
  cmd.run:
    - name: "ovs-vsctl add-port br-proxy proxy-veth-{{ bridge }}"
    - unless: "ovs-vsctl list-ports br-proxy | grep proxy-veth-{{ bridge }}"
    - require:
      - cmd: openvswitch_veth_{{ bridge }}_create


openvswitch_proxy-veth-{{ bridge }}_up:
  cmd.run:
    - name: "ip link set proxy-veth-{{ bridge }} up promisc on"
    - require:
      - cmd: openvswitch_proxy-veth-{{ bridge }}_add
  {% endif %}
{% endfor %}
