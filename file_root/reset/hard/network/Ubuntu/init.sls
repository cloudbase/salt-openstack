{% set openvswitch = salt['openstack_utils.openvswitch']() %}


hard_reset_network_openvswitch_promisc_delete:
  file.absent:
    - name: "{{ openvswitch['conf']['promisc_interfaces'] }}"
