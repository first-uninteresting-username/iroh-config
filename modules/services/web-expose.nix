# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = import ./web-settings.nix {inherit config lib;};

  routerAuth = r:
    if r.oidcPlugin != null && r.oidcPlugin.enable
    then null
    else if r.auth != null
    then r.auth
    else if r.public
    then cfg.authelia.defaultPolicy
    else null;

  effectiveRouters = lib.mapAttrs (_name: r: r // {auth = routerAuth r;}) cfg.routers;

  authRouters = lib.filterAttrs (_: r: r.auth != null) effectiveRouters;
  oidcRouters = lib.filterAttrs (_: r: r.oidc != null) effectiveRouters;
  oidcPluginRouters =
    lib.filterAttrs (
      _: r: r.oidcPlugin != null && r.oidcPlugin.enable
    )
    effectiveRouters;
  anyAuth = authRouters != {};
  anyOidc = oidcRouters != {};
  anyOidcPlugin = oidcPluginRouters != {};

  lldapBootstrap = let
    configHash = builtins.hashString "sha256" (
      builtins.toJSON {
        groups = cfg.lldap.bootstrap.groups;
        users = cfg.lldap.bootstrap.users;
      }
    );
  in
    pkgs.writeShellScript "lldap-bootstrap" ''
      set -euo pipefail
      MARKER="/var/lib/lldap/bootstrapped"
      CURRENT_HASH="${configHash}"

      if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$CURRENT_HASH" ]; then
        echo "LLDAP already bootstrapped with current configuration. Skipping."
        exit 0
      fi

      API="http://127.0.0.1:17170/graphql"
      ADMIN_USER="${cfg.lldap.adminUsername}"
      ADMIN_PASS="$(${pkgs.coreutils}/bin/cat "${cfg.lldap.adminPasswordFile}")"

      for i in $(seq 1 60); do
        if ${pkgs.curl}/bin/curl -sf "$API" -X POST \
          -H "Content-Type: application/json" \
          -d "$(${pkgs.jq}/bin/jq -n '{query: "{ __typename }"}')" >/dev/null 2>&1; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done

      TOKEN_RESP=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
        -H "Content-Type: application/json" \
        -d "$(${pkgs.jq}/bin/jq -n \
          --arg username "$ADMIN_USER" \
          --arg password "$ADMIN_PASS" \
          '{query: "mutation { bind(input: {username: \($username | @json), password: \($password | @json)}) { ok token } }"}')")
      if echo "$TOKEN_RESP" | ${pkgs.jq}/bin/jq -e '.errors' >/dev/null; then
        echo "Login failed: $(echo "$TOKEN_RESP" | ${pkgs.jq}/bin/jq -c '.errors')" >&2
        exit 1
      fi
      TOKEN=$(echo "$TOKEN_RESP" | ${pkgs.jq}/bin/jq -r '.data.bind.token')

      refresh_groups() {
        GROUPS_JSON=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $TOKEN" \
          -d "$(${pkgs.jq}/bin/jq -n '{query: "query { groups { id name } }"}')")
        if echo "$GROUPS_JSON" | ${pkgs.jq}/bin/jq -e '.errors' >/dev/null; then
          echo "Failed to fetch groups: $GROUPS_JSON" >&2
          exit 1
        fi
      }
      get_group_id() {
        echo "$GROUPS_JSON" | ${pkgs.jq}/bin/jq -r --arg name "$1" '.data.groups[] | select(.name == $name) | .id'
      }

      refresh_groups

      ${lib.concatMapStrings (g: ''
        GID=$(get_group_id "${g.name}")
        if [ -z "$GID" ]; then
          echo "Creating group ${g.name}..."
          RESP=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "$(${pkgs.jq}/bin/jq -n \
              --arg name "${g.name}" \
              '{query: "mutation CreateGroup($name: String!) { createGroup(name: $name) { ok } }", variables: {name: $name}}')")
          if echo "$RESP" | ${pkgs.jq}/bin/jq -e '.errors or (.data.createGroup.ok | not)' >/dev/null; then
            echo "Failed to create group ${g.name}: $RESP" >&2
            exit 1
          fi
          refresh_groups
        fi
      '') (lib.attrValues cfg.lldap.bootstrap.groups)}

      ${lib.concatMapStrings (u: ''
        ${lib.optionalString (u.passwordFile != null) ''
          USER_PASS=$(${pkgs.coreutils}/bin/cat "${toString u.passwordFile}")
        ''}

        # Check if user exists
        USER_EXISTS_RESP=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $TOKEN" \
          -d "$(${pkgs.jq}/bin/jq -n \
            --arg id "${u.id}" \
            '{query: "query GetUser($id: String!) { user(userId: $id) { id } }", variables: {id: $id}}')")

        if echo "$USER_EXISTS_RESP" | ${pkgs.jq}/bin/jq -e '.errors' >/dev/null; then
          echo "Failed to check user existence for ${u.id}: $USER_EXISTS_RESP" >&2
          exit 1
        fi

        USER_EXISTS=$(echo "$USER_EXISTS_RESP" | ${pkgs.jq}/bin/jq -r '.data.user.id // empty')

        if [ -z "$USER_EXISTS" ]; then
          echo "Creating user ${u.id}..."
          USER_VARS=$(${pkgs.jq}/bin/jq -n \
            --arg id "${u.id}" \
            --arg email "${u.email}" \
            ${lib.optionalString (u.displayName != null) ''--arg displayName "${u.displayName}"''} \
            ${lib.optionalString (u.firstName != null) ''--arg firstName "${u.firstName}"''} \
            ${lib.optionalString (u.lastName != null) ''--arg lastName "${u.lastName}"''} \
            ${lib.optionalString (u.passwordFile != null) ''--arg password "$USER_PASS"''} \
            '{
              id: $id,
              email: $email
              ${lib.optionalString (u.displayName != null) ", displayName: $displayName"}
              ${lib.optionalString (u.firstName != null) ", firstName: $firstName"}
              ${lib.optionalString (u.lastName != null) ", lastName: $lastName"}
              ${lib.optionalString (u.passwordFile != null) ", password: $password"}
            }')

          RESP=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TOKEN" \
            -d "$(${pkgs.jq}/bin/jq -n \
              --arg query 'mutation CreateUser($user: CreateUserInput!) { createUser(user: $user) { ok } }' \
              --argjson user "$USER_VARS" \
              '{query: $query, variables: {user: $user}}')")

          if echo "$RESP" | ${pkgs.jq}/bin/jq -e '.errors or (.data.createUser.ok | not)' >/dev/null; then
            echo "Failed to create user ${u.id}: $RESP" >&2
            exit 1
          fi
        fi

        # Get current user groups to avoid duplicate additions
        CURRENT_USER_GROUPS_RESP=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
          -H "Content-Type: application/json" \
          -H "Authorization: Bearer $TOKEN" \
          -d "$(${pkgs.jq}/bin/jq -n \
            --arg id "${u.id}" \
            '{query: "query GetUserGroups($id: String!) { user(userId: $id) { groups { name } } }", variables: {id: $id}}')")

        if echo "$CURRENT_USER_GROUPS_RESP" | ${pkgs.jq}/bin/jq -e '.errors' >/dev/null; then
          echo "Failed to fetch groups for user ${u.id}: $CURRENT_USER_GROUPS_RESP" >&2
          exit 1
        fi

        CURRENT_USER_GROUPS=$(echo "$CURRENT_USER_GROUPS_RESP" | ${pkgs.jq}/bin/jq -r '.data.user.groups[].name')

        ${lib.concatMapStrings (g: ''
            if ! echo "$CURRENT_USER_GROUPS" | grep -qxw "${g}" >/dev/null; then
              GID=$(get_group_id "${g}")
              if [ -n "$GID" ]; then
                echo "Adding user ${u.id} to group ${g}..."
                ADD_RESP=$(${pkgs.curl}/bin/curl -sf -X POST "$API" \
                  -H "Content-Type: application/json" \
                  -H "Authorization: Bearer $TOKEN" \
                  -d "$(${pkgs.jq}/bin/jq -n \
                    --arg query 'mutation AddUserToGroup($userId: String!, $groupId: Int!) { addUserToGroup(userId: $userId, groupId: $groupId) { ok } }' \
                    --arg userId "${u.id}" \
                    --argjson groupId "$GID" \
                    '{query: $query, variables: {userId: $userId, groupId: $groupId}}')")
                if echo "$ADD_RESP" | ${pkgs.jq}/bin/jq -e '.errors or (.data.addUserToGroup.ok | not)' >/dev/null; then
                  echo "Failed to add ${u.id} to group ${g}: $ADD_RESP" >&2
                  exit 1
                fi
              else
                echo "Warning: group ${g} not found for user ${u.id}" >&2
              fi
            fi
          '')
          u.groups}
      '') (lib.attrValues cfg.lldap.bootstrap.users)}

      echo "$CURRENT_HASH" > "$MARKER"
    '';

  oidcClientsTemplate = pkgs.writeText "oidc-clients-template.json" (
    builtins.toJSON (
      map (
        r: let
          o = r.oidc;
        in {
          inherit
            (o)
            client_id
            scopes
            grant_types
            response_types
            token_endpoint_auth_method
            consent_mode
            ;
          redirect_uris =
            o.redirect_uris
            ++ lib.optionals (r.oidcPlugin != null && r.oidcPlugin.enable) [
              "https://${r.subdomain}.${cfg.domain}/oauth2/callback"
            ];
        }
      ) (lib.attrValues oidcRouters)
    )
  );

  oidcPluginEnvGen = pkgs.writeShellScript "traefik-oidc-env" ''
    set -euo pipefail
    mkdir -p /var/lib/traefik
    ENV_FILE="/var/lib/traefik/oidc-plugin.env"
    install -m 600 -o traefik -g traefik /dev/null "$ENV_FILE"
    {
      echo "TRAEFIK_OIDC_SESSION_SECRET=$(${pkgs.coreutils}/bin/cat "${cfg.traefikOidcPlugin.sessionSecretFile}")"
      ${lib.concatStrings (
      lib.mapAttrsToList (name: r: ''
        echo "TRAEFIK_OIDC_CLIENT_SECRET_${
          lib.replaceStrings ["-"] ["_"] (lib.toUpper name)
        }=$(${pkgs.coreutils}/bin/cat "${r.oidcPlugin.clientSecretFile}")"
      '')
      oidcPluginRouters
    )}
    } > "$ENV_FILE"
  '';
in
  lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.authelia.enable || !anyAuth;
          message = "iroh web routing: routers request authentication but authelia.enable is false. Either enable authelia or set auth = null/bypass on all routers.";
        }
        {
          assertion = lib.all (r: !(r.oidc != null && r.auth != null && r.auth != "bypass")) (
            lib.attrValues effectiveRouters
          );
          message = "iroh web routing: routers with OIDC must set auth = 'bypass' or null to avoid double authentication loops.";
        }
        {
          assertion = !anyOidc || cfg.authelia.oidc.enable;
          message = "iroh web routing: routers have oidc configured but authelia.oidc.enable is false.";
        }
        {
          assertion = !anyOidcPlugin || cfg.authelia.oidc.enable;
          message = "iroh web routing: routers use oidcPlugin but authelia.oidc.enable is false.";
        }
        {
          assertion = lib.all (r: !(r.oidcPlugin != null && r.oidcPlugin.enable && r.oidc == null)) (
            lib.attrValues effectiveRouters
          );
          message = "iroh web routing: routers with oidcPlugin enabled must have an oidc client configured in Authelia.";
        }
        {
          assertion = lib.all (r: !(r.oidcPlugin != null && r.oidcPlugin.enable && r.auth != null)) (
            lib.attrValues effectiveRouters
          );
          message = "iroh web routing: routers with oidcPlugin enabled must not set auth (the plugin handles authentication).";
        }
        {
          assertion = !anyOidcPlugin || cfg.traefikOidcPlugin.enable;
          message = "iroh web routing: traefikOidcPlugin.enable must be true when a router uses oidcPlugin.";
        }
        {
          assertion = !cfg.traefikOidcPlugin.enable || cfg.traefikOidcPlugin.sessionSecretFile != null;
          message = "iroh web routing: traefikOidcPlugin.sessionSecretFile is required when the plugin is enabled.";
        }
        {
          assertion = !cfg.lldap.bootstrap.enable || cfg.lldap.enable;
          message = "iroh web routing: lldap.bootstrap.enable requires lldap.enable.";
        }
        {
          assertion = !cfg.authelia.enable || cfg.lldap.enable;
          message = "iroh web routing: authelia requires lldap (set lldap.enable = true).";
        }
      ];
    }

    {
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      services.traefik = {
        enable = true;
        environmentFiles =
          [
            cfg.traefikEnvFile
          ]
          ++ lib.optional anyOidcPlugin "/var/lib/traefik/oidc-plugin.env";

        staticConfigOptions =
          {
            entryPoints = {
              web = {
                address = ":80";
                http.redirections.entryPoint = {
                  to = "websecure";
                  scheme = "https";
                };
              };
              websecure = {
                address = ":443";
                http.middlewares = ["forwarded-proto"];
              };
            };
            certificatesResolvers.letsencrypt.acme = {
              inherit (cfg) email;
              storage = "/var/lib/traefik/acme.json";
              dnsChallenge = {
                provider = cfg.dnsChallenge.provider;
                resolvers = [
                  "1.1.1.1:53"
                  "8.8.8.8:53"
                ];
              };
            };
            ping = {};
          }
          // lib.optionalAttrs cfg.traefikOidcPlugin.enable {
            experimental.plugins.traefik-oidc-auth = {
              moduleName = "github.com/sevensolutions/traefik-oidc-auth";
              version = cfg.traefikOidcPlugin.version;
            };
          };

        dynamicConfigOptions.http = {
          tls.options.default = {
            sniStrict = true;
            minVersion = "VersionTLS12";
            cipherSuites = [
              "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
              "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
              "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
              "TLS_AES_128_GCM_SHA256"
              "TLS_AES_256_GCM_SHA384"
              "TLS_CHACHA20_POLY1305_SHA256"
            ];
            curvePreferences = [
              "CurveP521"
              "CurveP384"
            ];
          };

          middlewares =
            {
              lan-only.ipAllowList.sourceRange = cfg.privateNetworkRanges;
              public-ratelimit.rateLimit = {
                average = 100;
                burst = 100;
              };
              security-headers.headers = {
                hostsProxyHeaders = ["X-Forwarded-Host"];
                stsSeconds = cfg.hstsSeconds;
                stsIncludeSubdomains = true;
                stsPreload = cfg.hstsSeconds > 0;
                forceSTSHeader = cfg.hstsSeconds > 0;
                customFrameOptionsValue = "SAMEORIGIN";
                browserXssFilter = true;
                referrerPolicy = "same-origin";
                permissionsPolicy = "camera=(), microphone=(), geolocation=(), payment=(), usb=(), vr=()";
                customResponseHeaders = {
                  X-Content-Type-Options = "nosniff";
                  X-Download-Options = "noopen";
                  X-Robots-Tag = "none,noarchive,nosnippet,notranslate,noimageindex,";
                  Referrer-Policy = "no-referrer";
                  server = "";
                };
              };
              forwarded-proto.headers.customRequestHeaders = {
                "X-Forwarded-Proto" = "https";
              };
              public.chain.middlewares = [
                "public-ratelimit"
                "security-headers"
              ];

              authelia = {
                forwardAuth = {
                  address = "http://127.0.0.1:9091/api/authz/forward-auth?authelia_url=https%3A%2F%2F${cfg.authelia.subdomain}.${cfg.domain}%2F";
                  trustForwardHeader = true;
                  authResponseHeaders = [
                    "Remote-User"
                    "Remote-Groups"
                    "Remote-Email"
                    "Remote-Name"
                  ];
                };
              };
            }
            // lib.optionalAttrs anyOidcPlugin (
              lib.mapAttrs' (
                name: r:
                  lib.nameValuePair "${name}-oidc-plugin" {
                    plugin.traefik-oidc-auth = {
                      Secret = "\${TRAEFIK_OIDC_SESSION_SECRET}";
                      Provider = {
                        Url = "https://${cfg.authelia.subdomain}.${cfg.domain}";
                        ClientId = r.oidcPlugin.clientId;
                        ClientSecret = "\${TRAEFIK_OIDC_CLIENT_SECRET_${
                          lib.replaceStrings ["-"] ["_"] (lib.toUpper name)
                        }}";
                      };
                      Scopes = r.oidcPlugin.scopes;
                      UsePkce = r.oidcPlugin.usePkce;
                    };
                  }
              )
              oidcPluginRouters
            );

          routers =
            (lib.mapAttrs (name: r: {
                rule = r.traefikRule;
                entryPoints = ["websecure"];
                service = r.subdomain;
                tls = {
                  certResolver = "letsencrypt";
                  options = "default";
                };
                middlewares = let
                  base =
                    if r.public
                    then ["public"]
                    else ["lan-only"];
                  authMw =
                    if r.oidcPlugin != null && r.oidcPlugin.enable
                    then ["${name}-oidc-plugin"]
                    else lib.optional (r.auth != null) "authelia";
                in
                  base ++ authMw;
              })
              effectiveRouters)
            // lib.optionalAttrs cfg.authelia.enable {
              authelia = {
                rule = "Host(`${cfg.authelia.subdomain}.${cfg.domain}`)";
                entryPoints = ["websecure"];
                service = "authelia";
                tls = {
                  certResolver = "letsencrypt";
                  options = "default";
                };
                middlewares = ["public"];
              };
            }
            // lib.optionalAttrs cfg.lldap.enable {
              lldap = {
                rule = "Host(`${cfg.lldap.subdomain}.${cfg.domain}`)";
                entryPoints = ["websecure"];
                service = "lldap";
                tls = {
                  certResolver = "letsencrypt";
                  options = "default";
                };
                middlewares = [
                  "lan-only"
                  "security-headers"
                ];
              };
            };

          services =
            (lib.mapAttrs (_: r: {
                loadBalancer =
                  {
                    servers = [
                      {url = "http://${r.host}:${builtins.toString r.port}";}
                    ];
                  }
                  // lib.optionalAttrs r.healthCheck.enable {
                    healthCheck = {
                      path = r.healthCheck.path;
                      interval = r.healthCheck.interval;
                    };
                  };
              })
              effectiveRouters)
            // lib.optionalAttrs cfg.authelia.enable {
              authelia.loadBalancer.servers = [
                {url = "http://127.0.0.1:9091";}
              ];
            }
            // lib.optionalAttrs cfg.lldap.enable {
              lldap.loadBalancer.servers = [
                {url = "http://127.0.0.1:17170";}
              ];
            };
        };
      };

      systemd.services.traefik = lib.mkIf anyOidcPlugin {
        preStart = ''
          ${oidcPluginEnvGen}
        '';
      };
    }

    (lib.mkIf cfg.lldap.enable {
      users = {
        users.lldap = lib.mkDefault {
          isSystemUser = true;
          group = "lldap";
          home = "/var/lib/lldap";
        };

        groups.lldap = lib.mkDefault {};
      };

      services.lldap = {
        enable = true;
        settings = {
          ldap_base_dn = cfg.lldap.baseDn;
          ldap_user_dn = cfg.lldap.adminUsername;
          database_url = "sqlite:///var/lib/lldap/users.db?mode=rwc";
          force_ldap_user_pass_reset = "always";
        };
        environment = {
          LLDAP_JWT_SECRET_FILE = cfg.lldap.jwtSecretFile;
          LLDAP_KEY_SEED_FILE = cfg.lldap.keySeedFile;
          LLDAP_LDAP_USER_PASS_FILE = cfg.lldap.adminPasswordFile;
        };
      };

      systemd.services.lldap-bootstrap = lib.mkIf cfg.lldap.bootstrap.enable {
        description = "Bootstrap LLDAP users and groups";
        after = [
          "lldap.service"
          "nss-user-lookup.target"
        ];
        requires = ["lldap.service"];
        wants = ["nss-user-lookup.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "lldap";
          Group = "lldap";
          ExecStart = lldapBootstrap;
        };
      };
    })

    (lib.mkIf (cfg.authelia.enable && cfg.authelia.sessionProvider == "valkey") {
      services.redis = {
        package = lib.mkForce pkgs.valkey;
        servers.authelia = {
          enable = true;
          bind = "127.0.0.1";
          port = 6379;
        };
      };
    })

    (lib.mkIf cfg.authelia.enable {
      services.authelia.instances.main = {
        enable = true;

        secrets = {
          jwtSecretFile = cfg.authelia.secrets.jwtSecretFile;
          sessionSecretFile = cfg.authelia.secrets.sessionSecretFile;
          storageEncryptionKeyFile = cfg.authelia.secrets.storageEncryptionKeyFile;
        };

        environmentVariables =
          {
            AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE = cfg.lldap.adminPasswordFile;
          }
          // lib.optionalAttrs anyOidc {
            X_AUTHELIA_CONFIG = "/var/lib/authelia-main/oidc-overlay.json";
          };

        settings = {
          theme = "auto";

          server = {
            address = "tcp://127.0.0.1:9091";
            endpoints.authz.forward-auth.implementation = "ForwardAuth";
          };

          log.level = "info";
          telemetry.metrics.enabled = false;

          authentication_backend = {
            ldap = {
              implementation = "lldap";
              address = "ldap://127.0.0.1:3890";
              base_dn = cfg.lldap.baseDn;
              user = "CN=${cfg.lldap.adminUsername},OU=people,${cfg.lldap.baseDn}";
            };
            password_reset.disable = true;
            password_change.disable = true;
          };

          access_control = {
            default_policy = cfg.authelia.defaultPolicy;
            rules =
              (lib.mapAttrsToList (_: r: {
                domain = ["${r.subdomain}.${cfg.domain}"];
                policy = "bypass";
                networks = cfg.privateNetworkRanges;
              }) (lib.filterAttrs (_: r: r.public && r.auth != null && r.auth != "bypass") effectiveRouters))
              ++ (lib.concatMap (
                r:
                  map (path: {
                    domain = ["${r.subdomain}.${cfg.domain}"];
                    policy = "bypass";
                    resources = [path];
                  })
                  r.bypassPaths
              ) (lib.attrValues authRouters))
              ++ (lib.mapAttrsToList (_: r: {
                  domain = ["${r.subdomain}.${cfg.domain}"];
                  policy = r.auth;
                  subject = r.subjects;
                  inherit (r) resources;
                  inherit (r) networks;
                  inherit (r) methods;
                })
                authRouters);
          };

          session =
            {
              name = "authelia_session";
              same_site = "lax";
              inactivity = "5m";
              expiration = "1h";
              remember_me = "1M";
              cookies = [
                {
                  inherit (cfg) domain;
                  authelia_url = "https://${cfg.authelia.subdomain}.${cfg.domain}";
                  name = "authelia_session";
                }
              ];
            }
            // lib.optionalAttrs (cfg.authelia.sessionProvider == "valkey") {
              redis.host = "127.0.0.1";
              redis.port = 6379;
            };

          regulation = {
            max_retries = 3;
            find_time = "2m";
            ban_time = "5m";
          };

          storage.local.path = "/var/lib/authelia-main/db.sqlite3";
          notifier.filesystem.filename = "/var/lib/authelia-main/notification.txt";
          webauthn.enable_passkey_login = true;
        };
      };

      systemd.services.authelia-main = {
        serviceConfig = {
          StateDirectory = "authelia-main";
          StateDirectoryMode = "0700";
        };
        # Wrap the pkgs.writeShellScript block inside string interpolation "${ ... }"
        preStart = lib.mkIf anyOidc "${pkgs.writeShellScript "authelia-oidc-setup" ''
          set -euo pipefail
          OUT="/var/lib/authelia-main/oidc-overlay.json"
          install -m 600 /dev/null "$OUT"
          CLIENTS=$(${pkgs.coreutils}/bin/cat ${oidcClientsTemplate})
          ${lib.concatMapStrings (
            r: let
              o = r.oidc;
            in ''
              HASH=$(${pkgs.coreutils}/bin/cat "${o.client_secret_hash_file}")
              CLIENTS=$(echo "$CLIENTS" | ${pkgs.jq}/bin/jq \
                --arg id "${o.client_id}" \
                --arg hash "$HASH" \
                'map(if .client_id == $id then . + {client_secret: $hash} else . end)')
            ''
          ) (lib.attrValues oidcRouters)}
          ${pkgs.jq}/bin/jq -n \
            --arg hmac "$(${pkgs.coreutils}/bin/cat ${cfg.authelia.oidc.hmacSecretFile})" \
            --arg key "$(${pkgs.coreutils}/bin/cat ${cfg.authelia.oidc.jwksRsaKeyFile})" \
            --argjson clients "$CLIENTS" \
            '{
              identity_providers: {
                oidc: {
                  hmac_secret: $hmac,
                  jwks: [{ algorithm: "RS256", use: "sig", key: $key }],
                  lifespans: {
                    access_token: "1h",
                    authorize_code: "1m",
                    id_token: "1h",
                    refresh_token: "90m"
                  },
                  clients: $clients
                }
              }
            }' > "$OUT"
        ''}";
      };
    })
  ]
