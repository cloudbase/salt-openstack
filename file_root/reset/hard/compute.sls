
####################################
###    COMPUTE NODE HARD RESET   ###
####################################


# MySQL client purge

{% if "mysql.client" in salt['pillar.get']('sls:compute') %}
compute_mysql_client_purge:
  pkg.purged:
    - pkgs:
      - {{ salt['pillar.get']('packages:mysql_common') }}
      - {{ salt['pillar.get']('packages:mysql_client_core') }}
{% endif %}


# Nova compute KVM purge

{% if 'nova.compute_kvm' in salt['pillar.get']('sls:compute') %}
compute_destroy_nova_vms_script_create:
  file: 
    - managed
    - user: root
    - group: root
    - mode: 400
    - name: "/tmp/nova-vms-cleanup.sh"
    - contents: |
        #!/bin/bash
        virsh list --all
        if [ $? -eq 127 ]; then
            echo "Libvirt is not installed"
            exit 0
        fi
        for x in $(virsh list --all | grep -E "instance-[0-9a-fA-F]{8}" | awk '{print $2}') ; do
            virsh destroy $x ;
            virsh undefine $x ;
        done ;

compute_destroy_nova_vms_script_create_run:
  cmd:
    - run
    - name: "bash /tmp/nova-vms-cleanup.sh"
    - require:
      - file: compute_destroy_nova_vms_script_create

compute_destroy_nova_vms_script_delete:
  file:
    - absent
    - name: "/tmp/nova-vms-cleanup.sh"

  {% set nova_compute_services = [ salt['pillar.get']('services:nova_compute') ] %}
  {% for service in nova_compute_services %}
compute_nova_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

compute_kvm_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:nova_compute') }}"
      - "{{ salt['pillar.get']('packages:nova_pythonclient') }}"
  {% if grains['os'] == 'Ubuntu' %}
      - "{{ salt['pillar.get']('packages:nova_compute_kvm') }}"
  {% endif %}
{% endif %}


# OpenvSwitch purge

{% if 'neutron.openvswitch' in salt['pillar.get']('sls:compute') %}
  {% for service in [ salt['pillar.get']('services:neutron_l2_agent'),
                      salt['pillar.get']('services:openvswitch') ] %}
compute_neutron_openvswitch_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

compute_neutron_openvswitch_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:openvswitch') }}"
      - "{{ salt['pillar.get']('packages:openvswitch_common') }}"

compute_neutron_openvswitch_promisc_script_delete: 
  file.absent:
    - name: "{{ salt['pillar.get']('conf_files:openstack_promisc_interfaces') }}"

  {% if grains['os'] == 'CentOS' %}
compute_neutron_openvswitch_promisc_systemd_delete: 
  file.absent:
    - name: "{{ salt['pillar.get']('conf_files:openstack_promisc_interfaces_systemd') }}"

  {% endif %}
{% endif %}


# Neutron ML2 purge

{% if 'neutron.ml2' in salt['pillar.get']('sls:compute') %}
compute_neutron_ml2_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:neutron_ml2') }}"
{% endif %}

