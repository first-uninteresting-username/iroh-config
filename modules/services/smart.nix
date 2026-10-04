# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{pkgs, ...}: {
  preservation.preserveAt = {
    "/persist" = {
      directories = [
        "/var/lib/smartmontools"
      ];
    };
  };

  environment.systemPackages = with pkgs; [smartmontools];

  services.smartd = {
    enable = true;
    notifications = {
      systembus-notify.enable = true;
      wall.enable = true;
    };
    defaults.autodetected = "-a -s (S/../.././02)";
  };
}
