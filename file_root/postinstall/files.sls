{% from "cluster/resources.jinja" import get_candidate with context %}

keystone_admin_create:
  file: 
    - managed
    - group: root
    - mode: 644
    - name: {{ salt['pillar.get']('files:keystone_admin:path', default='/root/keystone_admin') }}
    - user: root
    - contents: |
        export OS_USERNAME=admin
        export OS_TENANT_NAME=admin
        export OS_PASSWORD={{ salt['pillar.get']('keystone:tenants:admin:users:admin:password') }}
        export OS_AUTH_URL={{ salt['pillar.get']('keystone:services:keystone:endpoint:publicurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
        export PS1='[\u@\h \W(keystone_admin)]\$ '
