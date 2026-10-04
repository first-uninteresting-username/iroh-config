# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  networking = {
    networkmanager.enable = false;

    interfaces.enp1s0 = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "192.168.0.10";
          prefixLength = 24;
        }
      ];
    };

    defaultGateway = "192.168.0.1";
    nameservers = ["1.1.1.1" "1.0.0.1"];

    firewall = {
      enable = true;
    };
  };
}
