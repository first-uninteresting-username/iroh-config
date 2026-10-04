# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{config, ...}: let
  sshDir = "/persist";
in {
  programs.ssh.startAgent = true;
  systemd.tmpfiles.rules = [
    "d ${config.users.users.nixi.home}/.ssh 0700 nixi users - -"
  ];
  users.users.nixi = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPGzRUdlC8OdgeZhL9Kn+57GHAmMpkfBG3iqPl3dRYTM Desktop_key"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFb1ByQK+SH7b7ZD+Epe5zYDyOUp2V0Sr/GcAfKy8J4y Laptop_key"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPhyyqVG8KdfHL00jBin/8rJzaD1Str3lO7N+IeF8fPI Server_key"
    ];
  };
  # This is either the worst or the smartest thing in the history of humanity, nothing in between
  sops.secrets."ssh_keys/private/${config.networking.hostName}" = {
    owner = "nixi";
    inherit (config.users.users.nixi) group;
    mode = "0600";
    path = "${sshDir}${config.users.users.nixi.home}/.ssh/id_ed25519";
  };
  sops.secrets."ssh_keys/public/${config.networking.hostName}" = {
    owner = "nixi";
    inherit (config.users.users.nixi) group;
    mode = "0644";
    path = "${sshDir}${config.users.users.nixi.home}/.ssh/id_ed25519.pub";
  };

  preservation.preserveAt = {
    "/persist" = {
      users.nixi = {
        directories = [
          {
            directory = ".ssh";
            mode = "0700";
          }
        ];
      };
    };
  };

  home-manager.users.nixi = _: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings = {
        "*" = {
          IdentityFile = "~/.ssh/id_ed25519";
          AddKeysToAgent = "yes";
          IdentitiesOnly = "yes";
          ServerAliveInterval = "60";
          ServerAliveCountMax = "3";
          ConnectTimeout = "10";

          ForwardX11 = "no";
          ForwardX11Trusted = "no";
          PasswordAuthentication = "yes";
          VisualHostKey = "yes";
        };
        "Iroh" = {
          HostName = "iameasytoremember.duckdns.org";
          User = "nixi";
          Port = 6767;
          IdentityFile = "~/.ssh/id_ed25519";
        };
      };
    };
  };
}
