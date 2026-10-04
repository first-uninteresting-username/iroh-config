# iroh-config

Standalone NixOS configuration for `iroh`, restored from
[`first-uninteresting-username/NixOS-config`](https://github.com/first-uninteresting-username/NixOS-config)
at commit [`5f886d11c163dcea0eda59ae4e6a173a32bf05e7`](https://github.com/first-uninteresting-username/NixOS-config/commit/5f886d11c163dcea0eda59ae4e6a173a32bf05e7),
immediately before commit `e4aa2b4cedb3775d7f392b06c1baac67726b1ad2` deleted the host
on August 21, 2026.

The active configuration uses ordinary NixOS modules imported explicitly by
`hosts/iroh/default.nix`. Host settings use upstream NixOS and Home Manager
options directly. The login shell is zsh, with completion, autosuggestions,
syntax highlighting, Oh My Zsh, and the existing command-line tools.

`modules/system/` configures boot, persistence, networking, and secrets;
`modules/user/` configures the account, theme, Git, and Home Manager; and
`modules/shell/` configures zsh and its tools.

The service modules have been removed, including the home server, web routing,
authentication services, NAS, SSH client/server setup, SMART monitoring,
automatic updates, and container support. The archived AI and Nixflix service
sources and the update module's `rebuild` helper have also been removed.
The encrypted secret file remains intact; removed services no longer declare
or install their secrets.

The `config` Nix registry alias points to
`github:first-uninteresting-username/iroh-config/main`. Active dependency pins
remain at their recovered revisions. The NixOS and Home Manager state versions
remain `26.11`.

## Build and use

Clone this repository:

```sh
gh repo clone first-uninteresting-username/iroh-config
cd iroh-config
nix flake check --no-build --no-update-lock-file
nixos-rebuild build --flake .#iroh
```

After reviewing the build on `iroh`, activate it with:

```sh
sudo nixos-rebuild switch --flake .#iroh
```

The host retains its original disk identifiers in `hosts/iroh/disko.nix`,
including the NVMe root disk and the SSD mounted at `/var/lib`. The large HDD
is no longer configured. Its initrd recreates the root Btrfs subvolume at boot and
preserves state under `/persist`. Review that layout before installing on any
replacement hardware. Building the configuration does not partition disks or
activate it.

## Secrets

`secrets/secrets.yaml` is the original encrypted SOPS file. `.sops.yaml` retains
all original recipients; neither file has been decrypted or re-encrypted.
The shared encrypted file also contains entries used by other historical hosts.

`iroh` decrypts secrets using its original SSH host key at
`/persist/etc/ssh/ssh_host_ed25519_key`. Restore that key from your own backup
when recovering the machine. The repository contains no private age or SSH key.
Edit encrypted secrets with `sops` using an existing authorized age identity.

Rebuild from the local checkout using the commands above.

## License

GPL-3.0-or-later; original attribution and license headers are preserved.

## Validation

`nix flake check --no-build --no-update-lock-file` evaluates the `iroh` host and
helper packages. `nix fmt -- --check flake.nix hosts modules packages` checks
formatting. These checks do not execute a full system build or activate it.

The host retains the NVMe root disk, the persistent SSD mounted at `/var/lib`,
root rollback, the `nixi` user, and zsh. Service removal does not erase existing
service data on disk. The encrypted secrets and SOPS recipients are unchanged.
