{% from "cluster/resources.jinja" import get_candidate with context %}

{% for image_name in salt['pillar.get']('glance:images', ()) %}
openstack_image_{{ image_name }}:
  glance:
    - image_present
    - name: {{ image_name }}
    - connection_user: {{ salt['pillar.get']('glance:images:%s' % image_name).get('user', 'admin') }}
    - connection_tenant: {{ salt['pillar.get']('glance:images:%s' % image_name).get('tenant', 'admin') }}
    - connection_password: {{ salt['pillar.get']('keystone:tenants:%s:users:%s:password' % (salt['pillar.get']('glance:images:%s' % image_name).get('tenant', 'admin'), salt['pillar.get']('glance:images:%s' % image_name).get('user', 'admin'))) }}
    - connection_auth_url: {{ salt['pillar.get']('keystone:services:keystone:endpoint:internalurl').format(get_candidate(salt['pillar.get']('keystone:services:keystone:endpoint:endpoint_host_sls'))) }}
{% for image_attr in salt['pillar.get']('glance:images:%s' % image_name) %}
    - {{ image_attr }}: {{ salt['pillar.get']('glance:images:%s:%s' % (image_name, image_attr)) }}
{% if salt['pillar.get']('reset').lower() != None and salt['pillar.get']('reset').lower() == 'soft' %}
    - require:
      - cmd: glance_reset
{% endif %}
{% endfor %}
{% endfor %}
