hard_reset_clean_apt:
  cmd.run:
    - name: "apt-get autoremove -y && apt-get autoclean -y && apt-get clean -y"
