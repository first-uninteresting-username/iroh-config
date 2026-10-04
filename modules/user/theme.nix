# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [inputs.stylix.nixosModules.stylix];
  nix.settings = {
    extra-substituters = ["https://nix-community.cachix.org"];
    extra-trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
  };
  programs.dconf.enable = true;
  stylix = {
    autoEnable = false;
    enable = true;
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/gruvbox-dark.yaml";
    polarity = "dark";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    icons = {
      enable = true;
      package = pkgs.morewaita-icon-theme;
      dark = "MoreWaita";
      light = "MoreWaita";
    };
    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
      sansSerif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Sans";
      };
      serif = {
        package = pkgs.dejavu_fonts;
        name = "DejaVu Serif";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
    };
  };
  home-manager.users.nixi = {
    qt = {
      enable = true;
      style.name = lib.mkForce "breeze";
    };
    gtk.enable = true;
    stylix = {
      autoEnable = true;
      enable = true;
    };
  };
}
