# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  pkgs,
  lib,
  ...
}: {
  preservation.preserveAt = {
    "/persist" = {
      users.nixi = {
        directories = [
          ".config/git"
          ".config/gh"
        ];
      };
    };
  };

  programs.git.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    git
    gh
  ];

  sops.secrets = {
    "github_pat" = {
      owner = "nixi";
    };
  };
  home-manager.users.nixi = {
    pkgs,
    osConfig,
    ...
  }: {
    home.packages = with pkgs; [onefetch meld];
    programs = {
      git = {
        enable = true;
        settings = {
          user = {
            name = "First-Non-Interesting-Username";
            email = "janekmusin@proton.me";
          };
          push = {
            autoSetupRemote = true;
          };
          init.defaultBranch = "main";
          pull.rebase = true;
          rerere.enabled = true;
          merge.tool = "meld";
          mergetool.keepBackup = false;
          mergetool.trustExitCode = true;
        };
      };
      gh = {
        enable = true;
        settings = {
          git_protocol = "https";
          prompt = "enabled";
        };
      };
      zsh.initContent = ''
        export GH_TOKEN="$(cat ${osConfig.sops.secrets.github_pat.path})"
      '';
    };
  };
}
