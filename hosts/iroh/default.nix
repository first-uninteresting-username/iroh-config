# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  self,
  ...
}: {
  networking.hostName = "iroh";
  imports = [
    ./hardware.nix
    ../../modules/system/bootloader.nix
    ../../modules/system/locale.nix
    ../../modules/system/networking.nix
    ../../modules/system/nix.nix
    ../../modules/system/secrets.nix
    ../../modules/user/git.nix
    ../../modules/user/home-manager.nix
    ../../modules/user/xdg.nix
    ../../modules/system/sudo.nix
    ../../modules/system/tty.nix
    ../../modules/services/home-server.nix
    ../../modules/services/nas.nix
    ../../modules/services/smart.nix
    ../../modules/services/ssh.nix
    ../../modules/services/sshd.nix
    ../../modules/services/update.nix
    ../../modules/services/virtualization.nix
    ../../modules/shell/zsh.nix
    ../../modules/shell/programs.nix
    ../../modules/system/preservation.nix
    ../../modules/user/account.nix
    ../../modules/user/theme.nix
  ];
  home-manager.extraSpecialArgs = {inherit inputs self;};
}
