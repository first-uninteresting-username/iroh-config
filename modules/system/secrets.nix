# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  self,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
    ../shell/secrets.nix
  ];

  preservation.preserveAt = {
    "/persist" = {
      users.nixi = {
        directories = [".config/sops/age"];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    sops
    age
    ssh-to-age
    self.packages.${pkgs.stdenv.hostPlatform.system}.sops-easy
  ];

  sops = {
    defaultSopsFile = "${self}/secrets/secrets.yaml";
    age = {
      generateKey = false;
      sshKeyPaths = ["/persist/etc/ssh/ssh_host_ed25519_key"];
    };
  };
}
