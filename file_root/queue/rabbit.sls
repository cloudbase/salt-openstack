rabbitmq_server_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:rabbitmq') }}

rabbitmq_service_running:
  service:
    - running
    - enable: True
    - name: {{ salt['pillar.get']('services:rabbitmq') }}
    - require:
      - pkg: rabbitmq_server_install

rabbitmq_password_set:
  cmd:
    - run
    - name: rabbitmqctl change_password guest {{ salt['pillar.get']('rabbitmq:guest_password') }}
    - require:
      - service: rabbitmq_service_running
