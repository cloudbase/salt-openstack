####################################
###    COMPUTE NODE HARD RESET   ###
####################################


{% set script_path = "/tmp/nova-vms-cleanup.sh" %}
hard_reset_compute_destroy_vms_script:
  file.managed:
    - user: root
    - group: root
    - mode: 400
    - name: "{{ script_path }}"
    - contents: |
        #!/bin/bash
        virsh list --all 2>/dev/null
        if [ $? -eq 127 ]; then
            echo "Libvirt is not installed"
            exit 0
        fi
        for x in $(virsh list --all | grep -E "instance-[0-9a-fA-F]{8}" | awk '{print $2}') ; do
            virsh destroy $x ;
            virsh undefine $x ;
        done ;


hard_reset_compute_destroy_vms_run:
  cmd.run:
    - name: "bash {{ script_path }}"
    - require:
      - file: hard_reset_compute_destroy_vms_script


hard_reset_compute_destroy_vms_script_delete:
  file.absent:
    - name: "{{ script_path }}"


{% set compute_services = salt['openstack_utils.os_services']('compute') %}
{% for service in compute_services %}
hard_reset_compute_{{ service }}_stopped:
  service.dead:
    - enable: False
    - name: {{ service }}
{% endfor %}


{% set compute_packages = salt['openstack_utils.os_packages']('compute') %}
{% for pkg in compute_packages %}
hard_reset_compute_{{ pkg }}_purged:
  pkg.purged:
    - pkgs:
      - {{ pkg }}
{% endfor %}
