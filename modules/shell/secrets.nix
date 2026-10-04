# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{inputs, ...}: {
  sops.secrets."HACK_CLUB_AI_API_KEY" = {
    owner = "nixi";
  };

  home-manager.users.nixi = {osConfig, ...}: {
    imports = [inputs.hack.homeManagerModules.default];

    programs.hack = {
      enable = true;
      settings = {
        base_url = "https://ai.hackclub.com/proxy/v1";
        model = "deepseek/deepseek-v4-flash-0731";
        api_key_path = osConfig.sops.secrets.HACK_CLUB_AI_API_KEY.path;
      };
    };
  };
}
