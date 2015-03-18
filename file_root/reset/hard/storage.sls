
####################################
###    STORAGE NODE HARD RESET   ###
####################################


# MySQL client purge

{% if "mysql.client" in salt['pillar.get']('sls:storage') %}
storage_mysql_client_purge:
  pkg.purged:
    - pkgs:
      - {{ salt['pillar.get']('packages:mysql_common') }}
      - {{ salt['pillar.get']('packages:mysql_client_core') }}
{% endif %}


# Cinder volume purge

{% if "cinder.volume" in salt['pillar.get']('sls:storage') %}
  {% for service in [ salt['pillar.get']('services:cinder_volume') ] %}
storage_cinder_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

storage_cinder_volume_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:cinder_volume') }}"
  {% if grains['os'] == 'Ubuntu' %}
      - "{{ salt['pillar.get']('packages:cinder_common') }}"
  {% endif %}
      - "{{ salt['pillar.get']('packages:cinder_python') }}"
      - "{{ salt['pillar.get']('packages:cinder_pythonclient') }}"

storage_cinder_vg_delete:
  cmd:
    - run
    - name: vgremove -f {{ salt['pillar.get']('cinder:volumes_group_name') }}
    - onlyif: vgdisplay {{ salt['pillar.get']('cinder:volumes_group_name') }}

storage_cinder_pv_delete:
  cmd:
    - run
    - name: pvremove -y {{ salt['pillar.get']('cinder:loopback_device') }}
    - onlyif: pvdisplay {{ salt['pillar.get']('cinder:loopback_device') }}

storage_cinder_lv_delete:
  cmd:
    - run
    - name: losetup -d {{ salt['pillar.get']('cinder:loopback_device') }}
    - onlyif: losetup {{ salt['pillar.get']('cinder:loopback_device') }}

storage_cinder_losetup_disable:
  service.disabled:
    - name: {{ salt['pillar.get']('services:openstack_cinder_losetup') }}

storage_cinder_losetup_dead:
  service.dead:
    - name: {{ salt['pillar.get']('services:openstack_cinder_losetup') }}
  file.absent:
    - name: {{ salt['pillar.get']('conf_files:openstack_cinder_losetup') }}

{% endif %}
