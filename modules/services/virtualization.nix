# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{...}: {
  preservation.preserveAt = {
    "/persist" = {
      directories = [
        "/var/lib/containers"
      ];
      users.nixi = {
        directories = [
          ".local/share/containers"
          ".config/containers"
        ];
      };
    };
  };
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
