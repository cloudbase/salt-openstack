

# Delete remaining directories after packages purge

{% set DIRS = [ 'lib', 'etc' ] %}
{% set PKGS = ['mysql',   'rabbitmq', 'keystone', 'glance', 'nova', 'neutron', 
               'horizon', 'cinder',   'heat'] %}

{% for dir in DIRS %}
  {% for pkg in PKGS %}
    {% if salt['pillar.get']('%s:%s' % (dir, pkg)) != "" %}
{{ pkg }}_{{ dir }}_delete:
  file.absent:
    - name: {{ salt['pillar.get']('%s:%s' % (dir, pkg)) }}
    - require:
      # Dependencies are dynamically generated

      # CONTROLLER NODE
      {% if grains['id'] == salt['pillar.get']('controller') %}
        {% if pkg == 'mysql' %}
          {% if 'mysql.client' in salt['pillar.get']('sls:network') %}
      - pkg: controller_{{ pkg }}_client_purge
          {% endif %}
      - pkg: controller_{{ pkg }}_purge
        {% elif pkg == 'rabbitmq' %}
          {% if 'queue.rabbit' in salt['pillar.get']('sls:controller') %}
      - pkg: controller_{{ pkg }}_purge
          {% endif %}
        {% elif pkg == 'neutron' %}
          {% if 'neutron.ml2' in salt['pillar.get']('sls:controller') %}
      - pkg: controller_{{ pkg }}_ml2_purge
          {% endif %}
      - pkg: controller_{{ pkg }}_purge
        {% elif pkg in salt['pillar.get']('sls:controller') %}
      - pkg: controller_{{ pkg }}_purge
        {% endif %}
      {% endif %}

      # NETWORK NODE
      {% if grains['id'] == salt['pillar.get']('network') %}
        {% if pkg == 'mysql' %}
          {% if 'mysql.client' in salt['pillar.get']('sls:network') %}
      - pkg: network_{{ pkg }}_client_purge
          {% endif %}
        {% elif pkg == 'neutron' %}
          {% if 'neutron.services' in salt['pillar.get']('sls:network') %}
      - pkg: network_{{ pkg }}_services_purge
          {% endif %}
          {% if 'neutron.ml2' in salt['pillar.get']('sls:network') %}
      - pkg: network_{{ pkg }}_ml2_purge
          {% endif %}
          {% if 'neutron.openvswitch' in salt['pillar.get']('sls:network') %}
      - pkg: network_{{ pkg }}_openvswitch_purge
            {% if grains['os'] == 'CentOS' %}
      - file: network_neutron_openvswitch_promisc_script_delete
      - file: network_neutron_openvswitch_promisc_systemd_delete
            {% endif %}
          {% endif %}
        {% elif pkg in salt['pillar.get']('sls:network') %}
      - pkg: network_{{ pkg }}_purge
        {% endif %}
      {% endif %}

      # COMPUTE NODE
      {% if grains['id'] in salt['pillar.get']('compute') %}
        {% if pkg == 'mysql' %}
          {% if 'mysql.client' in salt['pillar.get']('sls:compute') %}
      - pkg: compute_{{ pkg }}_client_purge
          {% endif %}
        {% elif pkg == 'nova' %}
          {% if 'nova.compute_kvm' in salt['pillar.get']('sls:compute') %}
      - pkg: compute_kvm_purge
          {% endif %}
        {% elif pkg == 'neutron' %}
          {% if 'neutron.openvswitch' in salt['pillar.get']('sls:compute') %}
      - pkg: compute_{{ pkg }}_openvswitch_purge
            {% if grains['os'] == 'CentOS' %}
      - file: compute_neutron_openvswitch_promisc_script_delete
      - file: compute_neutron_openvswitch_promisc_systemd_delete
            {% endif %}
          {% endif %}
          {% if 'neutron.ml2' in salt['pillar.get']('sls:compute') %}
      - pkg: compute_{{ pkg }}_ml2_purge
          {% endif %}
        {% elif pkg in salt['pillar.get']('sls:compute') %}
      - pkg: compute_{{ pkg }}_purge
        {% endif %}
      {% endif %}

      # STORAGE NODE
      {% if grains['id'] in salt['pillar.get']('storage') %}
        {% if pkg == 'mysql' %}
          {% if 'mysql.client' in salt['pillar.get']('sls:storage') %}
      - pkg: storage_{{ pkg }}_client_purge
          {% endif %}
        {% elif pkg == 'cinder' %}
          {% if 'cinder.volume' in salt['pillar.get']('sls:storage') %}
      - pkg: storage_{{ pkg }}_volume_purge
          {% endif %}
        {% elif pkg in salt['pillar.get']('sls:storage') %}
      - pkg: storage_{{ pkg }}_purge
        {% endif %}
      {% endif %}
    {% endif %}
  {% endfor %}
{% endfor %}


{% if grains['os'] == 'Ubuntu' %}


# Remove Ubuntu cloud keyring repository containing OpenStack Juno packages

ubuntu_cloud_keyring_purge:
  pkg.purged:
    - name: {{ salt['pillar.get']('packages:ubuntu-cloud-keyring') }}

cloudarchive_juno_delete:
  file.absent:
    - name: {{ salt['pillar.get']('conf_files:cloud_archive_juno') }}

apt_get_cleanup_commands:
  cmd.run:
    - name: "apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y"

{% endif %}
