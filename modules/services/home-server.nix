# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  lib,
  config,
  pkgs,
  ...
}: let
  domain = "iameasytoremember.duckdns.org";
  filebrowserStateDir = "/var/lib/filebrowser";
in {
  imports = [
    ./web-expose.nix
    # ../../archive/nixflix.nix
    # ../../archive/ai-services.nix
  ];

  preservation.preserveAt = {
    "/persist" = {
      directories = ["/var/cache/netdata"];
    };
  };

  sops.secrets = {
    "routing/traefik/env" = {
      owner = "traefik";
    };
    "routing/traefik/oidc-session" = {
      owner = "traefik";
    };

    "routing/lldap/admin-password" = {
      mode = "0444";
      owner = "lldap";
    };
    "routing/lldap/jwt-secret" = {
      mode = "0444";
      owner = "lldap";
    };
    "routing/lldap/key-seed" = {
      mode = "0444";
      owner = "lldap";
    };

    "routing/authelia/jwt-secret" = {
      owner = "authelia-main";
    };
    "routing/authelia/session-secret" = {
      owner = "authelia-main";
    };
    "routing/authelia/storage-key" = {
      owner = "authelia-main";
    };
    "routing/authelia/oidc-hmac" = {
      owner = "authelia-main";
    };
    "routing/authelia/oidc-jwks" = {
      owner = "authelia-main";
    };

    "routing/users/admin-user-password" = {
      mode = "0444";
    };

    "searx/env" = {
      owner = "searx";
    };

    "freshrss/oidc-client-secret" = {
      owner = "traefik";
    };
    "freshrss/oidc-client-secret-hash" = {
      owner = "authelia-main";
    };
    "freshrss/oidc-env" = {};

    "filebrowser/env" = {};
    "filebrowser/oidc-client-secret-hash" = {
      owner = "authelia-main";
    };

    "headplane/cookie-secret" = {
      owner = "headscale";
    };
    "headplane/oidc-client-secret" = {
      owner = "headscale";
    };
    "headplane/oidc-client-secret-hash" = {
      owner = "authelia-main";
    };
    "headscale/api-key" = {
      owner = "headscale";
    };

    "aria2/rpc-token" = {
      owner = "aria2";
    };

    "fgc/env" = {};

    "aiostreams/env" = {};
  };

  virtualisation.oci-containers = {
    backend = "podman";
    containers = {
      freshrss = {
        # renovate: versioning=docker
        image = "ghcr.io/freshrss/freshrss:1.29.1";

        environment = {
          TZ = "Europe/Warsaw";
          CRON_MIN = "1,31";
          OIDC_ENABLED = "1";
          OIDC_PROVIDER_METADATA_URL = "https://auth.${domain}/.well-known/openid-configuration";
          OIDC_CLIENT_ID = "freshrss";
          OIDC_SCOPES = "openid profile";
          OIDC_REMOTE_USER_CLAIM = "preferred_username";
          OIDC_X_FORWARDED_HEADERS = "X-Forwarded-Host X-Forwarded-Port X-Forwarded-Proto";
        };

        environmentFiles = [config.sops.secrets."freshrss/oidc-env".path];

        volumes = [
          "/var/lib/freshrss/data:/var/www/FreshRSS/data:U"
          "/var/lib/freshrss/extensions:/var/www/FreshRSS/extensions:U"
        ];

        ports = ["127.0.0.1:8035:80"];
      };

      filebrowser = {
        # renovate: versioning=docker
        image = "ghcr.io/gtsteffaniak/filebrowser:1.5.2-stable";

        environment = {
          TZ = "Europe/Warsaw";
        };
        environmentFiles = [
          config.sops.secrets."filebrowser/env".path
        ];

        ports = ["127.0.0.1:7070:80"];

        volumes = [
          "${filebrowserStateDir}:/home/filebrowser/data:U"
          "/etc/filebrowser-config.yaml:/home/filebrowser/data/config.yaml:ro"
          "/var/lib/storage:/sources/mnt-storage:ro"
          "/var/lib:/sources/var-lib:ro"
        ];
      };

      up-snap = {
        # renovate: versioning=docker
        image = "ghcr.io/seriousm4x/upsnap:5.4.4";
        environment = {
          TZ = "Europe/Warsaw";
          UPSNAP_PING_PRIVILEGED = "true";
          UPSNAP_HTTP_LISTEN = "127.0.0.1:8090";
        };

        volumes = ["/var/lib/up-snap:/app/pb_data:U"];

        extraOptions = [
          "--network=host"
          "--cap-add=NET_RAW"
        ];
      };

      qbittorrent = {
        # renovate: versioning=docker extractVersion=^(?<version>\d+\.\d+\.\d+_v\d+\.\d+\.\d+-ls\d+)$
        image = "lscr.io/linuxserver/qbittorrent:5.2.0_v2.0.12-ls458";
        autoStart = true;

        ports = [
          "127.0.0.1:8585:8585"
          "127.0.0.1:6881:6881"
          "127.0.0.1:6881:6881/udp"
        ];

        environment = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Europe/Warsaw";
          WEBUI_PORT = "8585";
        };

        volumes = [
          "/var/lib/qbittorrent/config:/config:U"
          "/var/lib/storage/qbittorrent/downloads:/downloads:U"
        ];
      };

      freeGames = {
        # renovate: versioning=docker
        image = "ghcr.io/feldorn/free-games-claimer:a7d40b2";
        autoStart = true;
        ports = [
          "127.0.0.1:6080:6080"
          "127.0.0.1:7080:7080"
        ];
        environment = {
          TZ = "Europe/Warsaw";
          PUBLIC_URL = "https://fgc.${domain}";
        };
        volumes = ["/var/lib/fgc:/fgc/data:U"];
        environmentFiles = [
          config.sops.secrets."fgc/env".path
        ];
      };

      aiostreams = {
        # renovate: versioning=docker
        image = "ghcr.io/viren070/aiostreams:v2.33.2";
        ports = ["127.0.0.1:4321:3000"];
        volumes = [
          "/var/lib/aiostreams/data:/app/data:U"
        ];
        environment = {
          TZ = "Europe/Warsaw";
          BASE_URL = "https://aiostreams.${domain}";
        };
        environmentFiles = [
          config.sops.secrets."aiostreams/env".path
        ];
        autoStart = true;
      };
    };
  };

  services = {
    irqbalance.enable = true;
    redis = {
      package = pkgs.valkey;
      servers = {
        searxng = {
          enable = true;
          bind = "127.0.0.1";
          port = 6380;
        };
      };
    };

    searx = {
      enable = true;
      openFirewall = true;
      settings = {
        server = {
          bind_address = "127.0.0.1";
          port = 8889;
          secret_key = "@SEARX_SECRET_KEY@";
          public_instance = false;
          image_proxy = true;
          base_url = "search.${domain}";
        };
        search = {
          safe_search = 0;
          formats = [
            "html"
            "json"
          ];
        };
        valkey = {
          url = "valkey://127.0.0.1:6380/0";
        };
        engines = [
          {
            name = "wolframalpha";
            engine = "wolframalpha_noapi";
            shortcut = "wa";
            categories = "general";
            disabled = false;
          }
          {
            name = "internet archive";
            engine = "internet_archive";
            shortcut = "ia";
            categories = "files";
            disabled = false;
          }
        ];
      };
      environmentFile = config.sops.secrets."searx/env".path;
      limiterSettings = {
        botdetection = {
          ip_limit = {
            filter_link_local = true;
            link_token = true;
          };
          ip_lists = {
            pass_searxng_org = true;
          };
        };
      };
    };

    netdata = {
      enable = true;

      config = {
        global = {
          "memory mode" = "dbengine";
          "history" = "14";
          "debug log" = "none";
          "access log" = "none";
          "error log" = "syslog";
        };

        web = {
          "bind to" = "localhost";
          "default port" = "19999";
        };
      };
    };

    cockpit = {
      enable = true;
      port = 9090;
      openFirewall = false;

      plugins = [pkgs.cockpit-files];

      settings = {
        WebService = {
          Origins = lib.mkForce "https://cockpit.${domain}";
        };
      };
    };

    headscale = {
      enable = true;
      address = "127.0.0.1";
      port = 9092;
      settings = {
        server_url = "https://tailscale.${domain}";
        dns.base_domain = "ts.${domain}";
        dns.magic_dns = true;
        dns.nameservers.global = [
          "1.1.1.1"
          "8.8.8.8"
        ];
        prefixes = {
          v4 = "100.64.0.0/10";
          v6 = "fd7a:115c:a1e0::/48";
        };
        logtail.enabled = false;
        derp.server.enabled = false;
      };
    };

    headplane = {
      enable = true;
      settings = {
        server = {
          host = "127.0.0.1";
          port = 4444;
          cookie_secret_path = config.sops.secrets."headplane/cookie-secret".path;
          cookie_secure = true;
          data_path = "/var/lib/headplane";
        };

        headscale = {
          url = "https://tailscale.${domain}";
          api_key_path = config.sops.secrets."headscale/api-key".path;
          config_path = (pkgs.formats.yaml {}).generate "headscale.yml" (
            lib.recursiveUpdate config.services.headscale.settings {
              tls_cert_path = "/dev/null";
              tls_key_path = "/dev/null";
              policy.path = "/dev/null";
            }
          );
          config_strict = true;
        };

        integration.proc.enabled = true;

        oidc = {
          issuer = "https://auth.${domain}";
          client_id = "headplane";
          client_secret_path = config.sops.secrets."headplane/oidc-client-secret".path;
          token_endpoint_auth_method = "client_secret_basic";
          disable_api_key_login = true;
        };
      };
    };

    aria2 = {
      enable = true;
      openPorts = true;
      settings = {
        enable-rpc = true;
        rpc-listen-all = true;
        rpc-listen-port = 6800;
        rpc-allow-origin-all = true;
        dir = "/var/lib/storage/aria2/downloads";
      };
      rpcSecretFile = config.sops.secrets."aria2/rpc-token".path;
    };
    nginx = {
      enable = true;
      virtualHosts."localhost" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 1357;
          }
        ];
        root = "${pkgs.ariang}/share/ariang";
      };
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d /var/lib/storage 0755 root root -"
      "d /var/lib/storage/aria2 0755 aria2 aria2 - -"
      "d /var/lib/storage/aria2/downloads 0755 aria2 aria2 - -"
      "d /var/lib/storage/qbittorrent 0755 root root -"
      "d /var/lib/storage/qbittorrent/downloads 0755 root root -"
      "d /var/lib 0755 root root -"
      "d /var/lib/aiostreams/data 0755 root root -"
      "d /var/lib/fgc 0755 root root -"
      "d /var/lib/filebrowser 0755 root root -"
      "d /var/lib/freshrss/data 0755 root root -"
      "d /var/lib/freshrss/extensions 0755 root root -"
      "d /var/lib/headplane 0750 headscale headscale -"
      "d /var/lib/qbittorrent/config 0755 root root -"
      "d /var/lib/up-snap 0755 root root -"
    ];
    services.duckdns-updater = {
      description = "Update DuckDNS IP";
      path = [pkgs.curl];

      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.secrets."routing/traefik/env".path;
      };

      script = ''
        curl -s "https://www.duckdns.org/update" --url-query "domains=${domain}" --url-query "token=$DUCKDNS_TOKEN"
      '';
    };
    timers.duckdns-updater = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1m";
        OnUnitActiveSec = "15m";
        RandomizedDelaySec = "1m";
      };
    };
  };

  environment.etc = {
    "filebrowser-config.yaml".text = ''
      server:
        port: 80
        database: "/home/filebrowser/data/database.db"
        cacheDir: "/home/filebrowser/data/tmp"
      sources:
        - path: "/sources/mnt-data"
          config:
            defaultEnabled: true
        - path: "/sources/var-lib"
          config:
            defaultEnabled: true
      auth:
        methods:
          password:
            enabled: true
          oidc:
            enabled: true
            clientId: "filebrowser"
            issuerUrl: "https://auth.${domain}"
            scopes: "openid email profile groups"
            userIdentifier: "preferred_username"
    '';
  };

  networking.firewall = {
    allowedUDPPorts = [41641];
    allowedTCPPortRanges = [
      {
        from = 10000;
        to = 11000;
      }
    ];
    trustedInterfaces = ["tailscale0"];
  };
}
