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


{% set index = 1 %}
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
    - name: "ip link add veth-proxy-{{ index }} type veth peer name veth-{{ index }}-proxy"
    - unless: "ip link list | egrep veth-proxy-{{ index }}"
    - require:
      - cmd: openvswitch_bridge_{{ bridge }}_up


openvswitch_veth-{{ index }}-proxy_add:
  cmd.run:
    - name: "ovs-vsctl add-port {{ bridge }} veth-{{ index }}-proxy"
    - unless: "ovs-vsctl list-ports {{ bridge }} | grep veth-{{ index }}-proxy"
    - require:
      - cmd: openvswitch_veth_{{ bridge }}_create


openvswitch_veth-{{ index }}-proxy_up:
  cmd.run:
    - name: "ip link set veth-{{ index }}-proxy up promisc on"
    - require:
      - cmd: openvswitch_veth-{{ index }}-proxy_add


openvswitch_veth-proxy-{{ index }}_add:
  cmd.run:
    - name: "ovs-vsctl add-port br-proxy veth-proxy-{{ index }}"
    - unless: "ovs-vsctl list-ports br-proxy | grep veth-proxy-{{ index }}"
    - require:
      - cmd: openvswitch_veth_{{ bridge }}_create


openvswitch_veth-proxy-{{ index }}_up:
  cmd.run:
    - name: "ip link set veth-proxy-{{ index }} up promisc on"
    - require:
      - cmd: openvswitch_veth-proxy-{{ index }}_add
  {% endif %}
  {% set index = index + 1 %}
{% endfor %}
