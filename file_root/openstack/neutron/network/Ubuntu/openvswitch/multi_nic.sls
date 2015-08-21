{% set neutron = salt['openstack_utils.neutron']() %}
{% set openvswitch = salt['openstack_utils.openvswitch']() %}


openvswitch_interfaces_promisc_upstart_job:
  file.managed:
    - name: {{ openvswitch['conf']['promisc_interfaces'] }}
    - user: root
    - group: root
    - mode: 644
    - contents: |

        start on runlevel [2345]

        script
{% for bridge in neutron['bridges'] %}
  {% if neutron['bridges'][bridge] %}
            ip link set {{ neutron['bridges'][bridge] }} up promisc on
  {% endif %}
{% endfor %}
        end script
    - require:
{% for bridge in neutron['bridges'] %}
  {% if neutron['bridges'][bridge] %}
      - cmd: openvswitch_interface_{{ bridge }}_{{ neutron['bridges'][bridge] }}_up
  {% endif %}
{% endfor %}
