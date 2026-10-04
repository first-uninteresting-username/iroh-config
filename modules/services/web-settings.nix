# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  config,
  lib,
  ...
}: let
  domain = "iameasytoremember.duckdns.org";
  email = "janekmusin@proton.me";
  settings =
    lib.recursiveUpdate {
      dnsChallenge.provider = "duckdns";
      privateNetworkRanges = ["192.168.0.0/16" "10.0.0.0/8" "172.16.0.0/12" "100.64.0.0/10"];
      hstsSeconds = 2592000;
      traefikOidcPlugin = {
        enable = false;
        version = "v0.18.0";
        sessionSecretFile = null;
      };
      authelia = {
        subdomain = "auth";
        defaultPolicy = "two_factor";
        sessionProvider = "valkey";
        oidc.enable = true;
      };
      lldap = {
        enable = true;
        subdomain = "ldap";
        adminUsername = "admin";
        baseDn = "DC=example,DC=com";
        bootstrap.enable = true;
        bootstrap.users.admin.id = "admin";
      };
    } {
      enable = true;
      inherit domain;
      inherit email;

      traefikEnvFile = config.sops.secrets."routing/traefik/env".path;

      lldap = {
        adminPasswordFile = config.sops.secrets."routing/lldap/admin-password".path;
        jwtSecretFile = config.sops.secrets."routing/lldap/jwt-secret".path;
        keySeedFile = config.sops.secrets."routing/lldap/key-seed".path;

        bootstrap = {
          groups.admins = {
            name = "admins";
          };
          groups.service-users = {
            name = "service-users";
          };
          users.admin = {
            inherit email;
            passwordFile = config.sops.secrets."routing/users/admin-user-password".path;
            displayName = "Admin";
            firstName = "Admin";
            lastName = "Admin";
            groups = [
              "admins"
              "service-users"
            ];
          };
        };
      };

      authelia = {
        enable = true;
        secrets = {
          jwtSecretFile = config.sops.secrets."routing/authelia/jwt-secret".path;
          sessionSecretFile = config.sops.secrets."routing/authelia/session-secret".path;
          storageEncryptionKeyFile = config.sops.secrets."routing/authelia/storage-key".path;
        };
        oidc = {
          hmacSecretFile = config.sops.secrets."routing/authelia/oidc-hmac".path;
          jwksRsaKeyFile = config.sops.secrets."routing/authelia/oidc-jwks".path;
        };
      };

      #traefikOidcPlugin = {
      #  enable = true;
      #  sessionSecretFile = config.sops.secrets."routing/traefik/oidc-session".path;
      #};

      routers = {
        searxng = {
          subdomain = "search";
          port = 8889;
          host = "127.0.0.1";
          public = true;
          auth = "two_factor";
          subjects = ["group:service-users"];
        };

        freshrss = {
          subdomain = "rss";
          port = 8035;
          public = true;
          auth = "bypass";

          oidc = {
            client_id = "freshrss";
            client_secret_hash_file = config.sops.secrets."freshrss/oidc-client-secret-hash".path;
            redirect_uris = ["https://rss.${domain}:443/i/oidc/"];
            scopes = [
              "openid"
              "profile"
            ];
          };
        };

        filebrowser = {
          subdomain = "files";
          port = 7070;
          public = true;
          auth = "bypass";

          oidc = {
            client_id = "filebrowser";
            client_secret_hash_file = config.sops.secrets."filebrowser/oidc-client-secret-hash".path;
            redirect_uris = ["https://files.${domain}/api/auth/oidc/callback"];
            scopes = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            token_endpoint_auth_method = "client_secret_basic";
          };
        };

        cockpit = {
          subdomain = "cockpit";
          port = 9090;
          public = true;
          auth = null;
        };

        netdata = {
          subdomain = "netdata";
          port = 19999;
          public = true;
          auth = "two_factor";
          subjects = ["group:service-users"];
        };

        up-snap = {
          subdomain = "up-snap";
          port = 8090;
          public = true;
          auth = "two_factor";
          subjects = ["group:service-users"];
        };

        headscale = {
          subdomain = "tailscale";
          port = 9092;
          host = "127.0.0.1";
          public = true;
          auth = null;
        };

        headplane = {
          subdomain = "headplane";
          port = 4444;
          host = "127.0.0.1";
          public = true;
          auth = "bypass";
          oidc = {
            client_id = "headplane";
            client_secret_hash_file = config.sops.secrets."headplane/oidc-client-secret-hash".path;
            redirect_uris = ["https://headplane.${domain}/admin/oidc/callback"];
            scopes = [
              "openid"
              "profile"
              "email"
              "groups"
            ];
            token_endpoint_auth_method = "client_secret_basic";
          };
        };

        ariang = {
          subdomain = "ariang";
          port = 1357;
          public = true;
          auth = "two_factor";
          subjects = ["group:service-users"];
        };

        qbittorrent = {
          subdomain = "qbittorrent";
          port = 8585;
          host = "127.0.0.1";
          public = true;
          auth = "two_factor";
          subjects = ["group:service-users"];
        };

        fgc = {
          subdomain = "fgc";
          port = 7080;
          public = false;
          auth = "two_factor";
          subjects = ["group:service-users"];
        };

        fgcNovnc = {
          subdomain = "fgc-novnc";
          port = 6080;
          public = false;
          auth = "two_factor";
          subjects = ["group:service-users"];
          traefikRule = ''Host(`fgc.${domain}`) && (PathPrefix(`/novnc`) || Path(`/websockify`))'';
        };

        aiostreams = {
          subdomain = "aiostreams";
          port = 4321;
          public = true;
          auth = "bypass";
        };
      };
    };
  routers = lib.mapAttrs (name: r:
    {
      host = "127.0.0.1";
      public = false;
      auth = null;
      subjects = [];
      resources = [];
      networks = [];
      methods = [];
      bypassPaths = [];
      traefikRule = "Host(`${r.subdomain}.${domain}`)";
      healthCheck = {
        enable = false;
        path = "/";
        interval = "10s";
      };
      oidcPlugin = null;
    }
    // r
    // {
      oidc =
        if r ? oidc
        then
          {
            client_id = name;
            scopes = ["openid" "profile" "email"];
            grant_types = ["authorization_code"];
            response_types = ["code"];
            token_endpoint_auth_method = "client_secret_post";
            consent_mode = "auto";
          }
          // r.oidc
        else null;
    })
  settings.routers;
in
  settings // {inherit routers;}
