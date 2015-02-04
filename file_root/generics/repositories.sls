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
