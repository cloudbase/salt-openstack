{% from "cluster/resources.jinja" import get_candidate with context %}
{% from "cluster/physical_networks.jinja" import bridges with context %}

neutron_l2_agent_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_l2_agent', default='neutron-plugin-openvswitch-agent') }}"
{% if bridges %}
    - require: 
{% for bridge in bridges %}
      - cmd: bridge_{{ bridge }}_create
{% endfor %}
{% endif %}

openvswitch_switch_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:openvswitch', default='openvswitch-switch') }}"

neutron_common_install: 
  pkg: 
    - installed
    - name: "{{ salt['pillar.get']('packages:neutron_common', default='neutron-common') }}"

l2_agent_neutron_config_file: 
  file: 
    - managed
    - name: "{{ salt['pillar.get']('conf_files:neutron', default='/etc/neutron/neutron.conf') }}"
    - group: neutron
    - user: neutron
    - mode: 644
    - require: 
      - ini: l2_agent_neutron_config_file
  ini: 
    - options_present
    - name: "{{ salt['pillar.get']('conf_files:neutron', default='/etc/neutron/neutron.conf') }}"
    - sections: 
        DEFAULT: 
          auth_strategy: keystone
          rpc_backend: neutron.openstack.common.rpc.impl_kombu
          rabbit_host: "{{ get_candidate('queue.%s' % salt['pillar.get']('queue_engine', default='rabbit')) }}"
          rabbit_password: {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: True
          verbose: True
        keystone_authtoken: 
          auth_uri: "http://{{ get_candidate('keystone') }}:5000"
          auth_host: "{{ get_candidate('keystone') }}"
          auth_protocol: http
          auth_port: 35357
          admin_tenant_name: service
          admin_user: neutron
          admin_password: "{{ salt['pillar.get']('keystone:tenants:service:users:neutron:password') }}"
    - require: 
      - pkg: neutron_l2_agent_install

{% for bridge in bridges %}
bridge_{{ bridge }}_create: 
  cmd: 
    - run
    - name: "ovs-vsctl add-br {{ bridge }}"
    - unless: "ovs-vsctl br-exists {{ bridge }}"
    - require: 
      - service: openvswitch_switch_running
{% if bridges[bridge] != None and bridges[bridge] != "None" %}
{{ bridge }}_interface_add:
  cmd:
    - run
    - name: "ovs-vsctl add-port {{ bridge }} {{ bridges[bridge] }}"
    - unless: "ovs-vsctl list-ports {{ bridge }} | grep {{ bridges[bridge] }}"
    - require: 
      - cmd: "bridge_{{ bridge }}_create"
{{ bridges[bridge] }}_interface_bring_up:
  cmd:
    - run
    - name: "ip link set {{ bridges[bridge] }} up promisc on"
    - require:
      - cmd: {{ bridge }}_interface_add
{% endif %}
{% endfor %}

openvswitch_switch_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:openvswitch', default='openvswitch-switch') }}"
    - require: 
      - pkg: openvswitch_switch_install
      - pkg: neutron_common_install

neutron_l2_agent_running:
  service: 
    - running
    - name: "{{ salt['pillar.get']('services:neutron_l2_agent', default='neutron-plugin-openvswitch-agent') }}"
    - require: 
      - pkg: neutron_l2_agent_install
    - watch: 
      - file: l2_agent_neutron_config_file
      - ini: l2_agent_neutron_config_file

neutron_ovs_wait:
  cmd:
    - run
    - name: sleep 5
    - require:
      - service: openvswitch_switch_running
      - service: neutron_l2_agent_running
