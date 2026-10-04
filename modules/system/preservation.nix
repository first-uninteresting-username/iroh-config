# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  imports = [inputs.preservation.nixosModules.preservation];

  boot = {
    initrd.systemd.enable = true;
    tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };
  };

  systemd = {
    suppressedSystemUnits = ["systemd-machine-id-commit.service"];
    services.systemd-machine-id-commit = {
      unitConfig.ConditionPathIsMountPoint = ["" "/persist/etc/machine-id"];
      serviceConfig.ExecStart = ["" "systemd-machine-id-setup --commit --root /persist"];
    };
    tmpfiles.rules = [
      "d /persist/home/nixi 0700 nixi users -"
    ];
  };

  preservation = {
    enable = true;
    preserveAt."/persist" = {
      commonMountOptions = ["x-gvfs-hide"];

      # /var/lib is on the dedicated persistent SSD.
      directories = ["/var/log"];

      files = [
        "/etc/adjtime"
        {
          file = "/etc/ssh/ssh_host_ed25519_key";
          how = "symlink";
          configureParent = true;
        }
        {
          file = "/etc/ssh/ssh_host_ed25519_key.pub";
          how = "symlink";
          configureParent = true;
        }
        {
          file = "/etc/machine-id";
          inInitrd = true;
          how = "symlink";
          configureParent = true;
        }
      ];

      users.nixi = {
        directories = [
          ".cache/mesa_shader_cache"
          "persist"
          ".cache/fontconfig"
        ];
      };
    };
  };

  fileSystems = {
    "/" = {
      neededForBoot = true;
    };
    "/nix" = {
      neededForBoot = true;
    };
    "/persist" = {
      neededForBoot = true;
    };
  };
  home-manager.users.nixi = _: {
    programs = {
      zsh.initContent = ''
        if [[ $PWD == $HOME ]]; then
            cd ~/persist
        fi
      '';
    };
  };
}
