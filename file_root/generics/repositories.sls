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
cloudarchive-juno_managed:
  file:
    - managed
    - append
    - name: /etc/apt/sources.list.d/cloudarchive-juno.list
    - text: "deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/juno main"
    - unless: cat /etc/apt/sources.list.d/cloudarchive-juno.list | egrep "deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/juno main"
	- user: root
	- group: root
	- mode: 755
{% endif %}