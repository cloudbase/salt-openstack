
####################################
###    NETWORK NODE HARD RESET   ###
####################################


# MySQL client purge

{% if "mysql.client" in salt['pillar.get']('sls:network') %}
network_mysql_client_purge:
  pkg.purged:
    - pkgs:
      - {{ salt['pillar.get']('packages:mysql_common') }}
      - {{ salt['pillar.get']('packages:mysql_client_core') }}
{% endif %}


# Neutron purge

{% if 'neutron.services' in salt['pillar.get']('sls:network') %}
  {% for service in [ salt['pillar.get']('services:neutron_l3_agent'),
                      salt['pillar.get']('services:neutron_dhcp_agent'),
                      salt['pillar.get']('services:neutron_metadata_agent') ] %}
network_neutron_services_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

network_neutron_services_purge:
  pkg.purged:
    - pkgs:
  {% if grains['os'] == 'Ubuntu' %}
      - "{{ salt['pillar.get']('packages:neutron_l3_agent') }}"
      - "{{ salt['pillar.get']('packages:neutron_dhcp_agent') }}"
      - "{{ salt['pillar.get']('packages:neutron_metadata_agent') }}"
  {% elif grains['os'] == 'CentOS' %}
      - "{{ salt['pillar.get']('packages:neutron_server') }}"
      - "{{ salt['pillar.get']('packages:neutron_python') }}"
      - "{{ salt['pillar.get']('packages:neutron_common') }}"
      - "{{ salt['pillar.get']('packages:neutron_pythonclient') }}"
  {% endif %}
{% endif %}

{% if 'neutron.ml2' in salt['pillar.get']('sls:network') %}
network_neutron_ml2_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:neutron_ml2') }}"
{% endif %}


# OpenvSwitch purge

{% if 'neutron.openvswitch' in salt['pillar.get']('sls:network') %}
  {% for service in [ salt['pillar.get']('services:neutron_l2_agent'),
                      salt['pillar.get']('services:openvswitch') ] %}
network_neutron_openvswitch_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

network_neutron_openvswitch_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:openvswitch') }}"
      - "{{ salt['pillar.get']('packages:openvswitch_common') }}"

network_neutron_openvswitch_promisc_script_delete: 
  file.absent:
    - name: "{{ salt['pillar.get']('conf_files:openstack_promisc_interfaces') }}"

  {% if grains['os'] == 'CentOS' %}
network_neutron_openvswitch_promisc_systemd_delete: 
  file.absent:
    - name: "{{ salt['pillar.get']('conf_files:openstack_promisc_interfaces_systemd') }}"

  {% endif %}
{% endif %}
