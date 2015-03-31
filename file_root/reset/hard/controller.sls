
######################################
###   CONTROLLER NODE HARD RESET   ###
######################################


# MySQL server and client purge

{% if "mysql" in salt['pillar.get']('sls:controller') %}
controller_mysql_service_stopped:
  service.dead:
    - name: {{ salt['pillar.get']('services:mysql') }}

controller_mysql_purge:
  pkg.purged:
    - pkgs:
      - {{ salt['pillar.get']('packages:mysql_server') }}
      - {{ salt['pillar.get']('packages:mysql_common') }}
      - {{ salt['pillar.get']('packages:mysql_server_core') }}
{% endif %}

{% if "mysql.client" in salt['pillar.get']('sls:controller') %}
controller_mysql_client_purge:
  pkg.purged:
    - pkgs:
      - {{ salt['pillar.get']('packages:mysql_common') }}
      - {{ salt['pillar.get']('packages:mysql_client_core') }}
{% endif %}


# RabbitMQ purge

{% if 'queue.rabbit' in salt['pillar.get']('sls:controller') %}
controller_rabbitmq_service_stopped:
  service.dead:
    - name: {{ salt['pillar.get']('services:rabbitmq') }}

controller_rabbitmq_purge:
  pkg.purged:
    - pkgs:
      - {{ salt['pillar.get']('packages:rabbitmq') }}
{% endif %}


# Keystone purge

{% if 'keystone' in salt['pillar.get']('sls:controller') %}
controller_keystone_service_stopped:
  service.dead:
    - name: {{ salt['pillar.get']('services:keystone') }}

controller_keystone_purge: 
  pkg.purged:
    - pkgs: 
      - {{ salt['pillar.get']('packages:keystone') }}
      - {{ salt['pillar.get']('packages:python_keystone') }}
{% endif %}


# Glance purge

{% if 'glance' in salt['pillar.get']('sls:controller') %}
  {% for service in [ salt['pillar.get']('services:glance_api'),
                      salt['pillar.get']('services:glance_registry') ] %}
controller_glance_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

controller_glance_purge: 
  pkg.purged:
    - pkgs: 
      - {{ salt['pillar.get']('packages:glance') }}
      - {{ salt['pillar.get']('packages:glance_pythonclient') }}
      - {{ salt['pillar.get']('packages:glance_common') }}
      - {{ salt['pillar.get']('packages:glance_python') }}
{% endif %}


# Nova purge

{% if 'nova' in salt['pillar.get']('sls:controller') %}
  {% for service in [ salt['pillar.get']('services:nova_api'),
                      salt['pillar.get']('services:nova_cert'),
                      salt['pillar.get']('services:nova_consoleauth'),
                      salt['pillar.get']('services:nova_scheduler'),
                      salt['pillar.get']('services:nova_conductor'),
                      salt['pillar.get']('services:nova_novncproxy') ] %}
controller_nova_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

controller_nova_purge: 
  pkg.purged:
    - pkgs: 
      - "{{ salt['pillar.get']('packages:nova_api') }}"
      - "{{ salt['pillar.get']('packages:nova_cert') }}"
      - "{{ salt['pillar.get']('packages:nova_conductor') }}"
      - "{{ salt['pillar.get']('packages:nova_consoleauth') }}"
      - "{{ salt['pillar.get']('packages:nova_novncproxy') }}"
      - "{{ salt['pillar.get']('packages:nova_scheduler') }}"
      - "{{ salt['pillar.get']('packages:nova_pythonclient') }}"
      - "{{ salt['pillar.get']('packages:nova_ajax_console_proxy') }}"
      - "{{ salt['pillar.get']('packages:nova_common') }}"
      - "{{ salt['pillar.get']('packages:nova_python') }}"
{% endif %}


# Neutron purge

{% if 'neutron' in salt['pillar.get']('sls:controller') %}
controller_neutron_service_stopped:
  service.dead:
    - name: {{ salt['pillar.get']('services:neutron_server') }}

controller_neutron_purge: 
  pkg.purged:
    - pkgs: 
      - "{{ salt['pillar.get']('packages:neutron_server') }}"
      - "{{ salt['pillar.get']('packages:neutron_python') }}"
      - "{{ salt['pillar.get']('packages:neutron_common') }}"
      - "{{ salt['pillar.get']('packages:neutron_pythonclient') }}"
{% endif %}

{% if 'neutron.ml2' in salt['pillar.get']('sls:controller') %}
controller_neutron_ml2_purge:
  pkg.purged:
    - pkgs:
      - "{{ salt['pillar.get']('packages:neutron_ml2') }}"
{% endif %}


# Horizon purge

{% if 'horizon' in salt['pillar.get']('sls:controller') %}
  {% for service in [ salt['pillar.get']('services:apache'),
                      salt['pillar.get']('services:memcached') ] %}
controller_horizon_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

controller_horizon_purge: 
  pkg.purged:
    - pkgs: 
      - "{{ salt['pillar.get']('packages:apache') }}"
      - "{{ salt['pillar.get']('packages:apache_wsgi_module') }}"
      - "{{ salt['pillar.get']('packages:memcached') }}"
      - "{{ salt['pillar.get']('packages:dashboard') }}"
      - "{{ salt['pillar.get']('packages:apache_data') }}"
      - "{{ salt['pillar.get']('packages:apache_bin') }}"
      - "{{ salt['pillar.get']('packages:python_memcache') }}"
{% endif %}


# Cinder purge

{% if 'cinder' in salt['pillar.get']('sls:controller') %}
  {% for service in [ salt['pillar.get']('services:cinder_api'),
                      salt['pillar.get']('services:cinder_scheduler') ] %}
controller_cinder_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

controller_cinder_purge: 
  pkg.purged:
    - pkgs: 
      - {{ salt['pillar.get']('packages:cinder_pythonclient') }}
  {% if grains['os'] == 'CentOS' %}
      - {{ salt['pillar.get']('packages:cinder_volume') }}
  {% endif %}
      - {{ salt['pillar.get']('packages:cinder_python') }}
  {% if grains['os'] == 'Ubuntu' %}
      - {{ salt['pillar.get']('packages:cinder_api') }}
      - {{ salt['pillar.get']('packages:cinder_scheduler') }}
      - {{ salt['pillar.get']('packages:cinder_common') }}
  {% endif %}
{% endif %}


# Heat purge

{% if 'heat' in salt['pillar.get']('sls:controller') %}
  {% for service in [ salt['pillar.get']('services:heat_api'),
                      salt['pillar.get']('services:heat_api_cfn'),
                      salt['pillar.get']('services:heat_engine') ] %}
controller_heat_{{ service }}_stopped:
  service.dead:
    - name: {{ service }}
  {% endfor %}

controller_heat_purge: 
  pkg.purged:
    - pkgs: 
      - {{ salt['pillar.get']('packages:heat_api') }}
      - {{ salt['pillar.get']('packages:heat_api_cfn') }}
      - {{ salt['pillar.get']('packages:heat_engine') }}
      - {{ salt['pillar.get']('packages:heat_python') }}
      - {{ salt['pillar.get']('packages:heat_common') }}
      - {{ salt['pillar.get']('packages:heat_pythonclient') }}
{% endif %}
