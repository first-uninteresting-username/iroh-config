# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{...}: {
  preservation.preserveAt = {
    "/persist" = {
      users.nixi = {
        directories = [
          ".config"
          ".local/share"
          ".local/state"
        ];
      };
    };
  };
  home-manager.users.nixi = {config, ...}: let
    homeBase = "${config.home.homeDirectory}/persist";
  in {
    systemd.user.tmpfiles.rules = [
      "d ${homeBase}/Games 0755 nixi nixi -"
    ];
    xdg = {
      enable = true;
      userDirs = {
        enable = true;
        createDirectories = true;
        desktop = null;
        download = "${homeBase}/Downloads";
        documents = "${homeBase}/Documents";
        pictures = "${homeBase}/Pictures";
        music = null;
        publicShare = null;
        templates = "${homeBase}/Templates";
        videos = "${homeBase}/Videos";
        projects = "${homeBase}/Projects";
        extraConfig = {
          XDG_GAMES_DIR = "${homeBase}/Games";
        };
      };
    };
  };
}
