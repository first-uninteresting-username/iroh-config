# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{...}: {
  preservation.preserveAt = {
    "/persist" = {
      directories = [
        "/var/lib/nfs"
      ];
    };
  };

  services.nfs.server = {
    enable = true;
    lockdPort = 4045;
    mountdPort = 4046;
    statdPort = 4047;
    exports = ''
      /mnt/storage  192.168.0.0/24(rw,sync,no_subtree_check,no_root_squash)
    '';
  };
  networking.firewall = {
    allowedTCPPorts = [111 2049 4045 4046 4047];
    allowedUDPPorts = [111 2049 4045 4046 4047];
  };
}
