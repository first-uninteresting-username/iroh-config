# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
  };
  home-manager.users.nixi = {
    osConfig,
    lib,
    ...
  }: {
    programs.home-manager.enable = true;
    home.homeDirectory = "/home/nixi";
    home.enableNixpkgsReleaseCheck = false;
    home.stateVersion = lib.mkDefault osConfig.system.stateVersion;
  };
}
