{% if grains['os'] == 'CentOS' %}
openstack_selinux_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:openstack_selinux') }}
    - require:
      - pkg: juno_repo_install
{% endif %}
