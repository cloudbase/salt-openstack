linux_headers_install:
  pkg:
    - installed
    - name: {{ salt['pillar.get']('packages:linux_headers') }}
