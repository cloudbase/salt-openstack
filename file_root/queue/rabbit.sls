rabbitmq_server_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:rabbitmq', default='rabbitmq-server') }}

rabbitmq_service_running:
  service:
    - running
    - name: {{ salt['pillar.get']('services:rabbitmq', default='rabbitmq-server') }}
    - require:
      - pkg: rabbitmq_server_install

rabbitmq_password_set:
  cmd:
    - run
    - name: rabbitmqctl change_password guest {{ salt['pillar.get']('rabbitmq:guest_password', default='Passw0rd') }}
    - require:
      - service: rabbitmq_service_running
