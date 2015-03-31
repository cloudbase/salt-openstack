{% if grains['os'] == 'CentOS' %}
yum_plugin_priorities_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:yum_plugin_priorities') }}

epel_repo_install:
  pkg:
    - installed
    - sources:
      - epel-release: "{{ salt['pillar.get']('packages:epel_repo') }}"

{% if pillar['cluster_type'] == 'juno' %}
juno_repo_install:
  pkg:
    - installed
    - sources:
      - rdo-release: "{{ salt['pillar.get']('packages:juno_repo') }}"
{% endif %}
{% endif %}

{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'Ubuntu' %}
ubuntu_cloud_keyring_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:ubuntu-cloud-keyring') }}

cloudarchive_juno:
  file:
    - append
    - name: {{ salt['pillar.get']('conf_files:cloud_archive_juno') }}
    - text: "deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/juno main"
    - unless: cat {{ salt['pillar.get']('conf_files:cloud_archive_juno') }} | egrep "deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/juno main"
    - user: root
    - group: root
    - mode: 644
{% endif %}
