# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  config,
  pkgs,
  ...
}: {
  users.mutableUsers = false;
  users.groups.nixi.gid = 1000;
  users.users.nixi = {
    isNormalUser = true;
    uid = 1000;
    group = "nixi";
    home = "/home/nixi";
    homeMode = "751";
    description = "nixi";
    extraGroups = ["wheel" "networkmanager" "video" "audio" "render" "gamemode" "input" "kvm" "netdev"];
    hashedPasswordFile = config.sops.secrets."sudo_password/iroh".path;
    subUidRanges = [
      {
        startUid = 100000;
        count = 65536;
      }
    ];
    subGidRanges = [
      {
        startGid = 100000;
        count = 65536;
      }
    ];
    linger = true;
    shell = pkgs.zsh;
  };
  sops.secrets."sudo_password/iroh".neededForUsers = true;
}
