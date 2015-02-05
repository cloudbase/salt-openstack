{% if grains['os'] == 'CentOS' %}
openstack_selinux_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:openstack_selinux') }}
    - require:
      - pkg: juno_repo_install
{% endif %}

{% if pillar['cluster_type'] == 'juno' and grains['os'] == 'Ubuntu' %}
ubuntu-cloud-keyring_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:ubuntu-cloud-keyring') }}
	- require:
      - file: /etc/apt/sources.list.d/cloudarchive-juno.list
{% endif %}