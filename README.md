# iroh-config

Standalone NixOS configuration for `iroh`, restored from
[`first-uninteresting-username/NixOS-config`](https://github.com/first-uninteresting-username/NixOS-config)
at commit [`5f886d11c163dcea0eda59ae4e6a173a32bf05e7`](https://github.com/first-uninteresting-username/NixOS-config/commit/5f886d11c163dcea0eda59ae4e6a173a32bf05e7),
immediately before commit `e4aa2b4cedb3775d7f392b06c1baac67726b1ad2` deleted the host
on August 21, 2026.

The repository contains the original host files, the shared modules needed by
`iroh`, its helper packages, and the original `flake.lock`. The home server,
NAS, reverse proxy, authentication, shell, and preservation configuration are
restored. The historical AI and Nixflix modules are included; their imports
remain commented out, as in the source configuration. Desktop and ISO hosts,
old CI workflows, and editor backup files are omitted.

The update service, `rebuild` helper, and `config` Nix registry alias point to
`github:first-uninteresting-username/iroh-config/main`. No other service settings
or dependency pins are changed. The NixOS and Home Manager state versions remain
`26.11`.

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
including the NVMe root disk, the SSD mounted at `/var/lib`, and the HDD mounted
at `/mnt/storage`. Its initrd recreates the root Btrfs subvolume at boot and
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

The existing remote update timer and `rebuild` helper fetch this GitHub repository.
Local rebuilds from a checkout also work.

## License

GPL-3.0-or-later; original attribution and license headers are preserved.

## Restoration validation

All retained Nix files parse. `nix flake check --no-build --no-update-lock-file`
passes for `x86_64-linux`, including evaluation of `nixosConfigurations.iroh`.
Alejandra's formatting check passes for the four adapted Nix files. The lock
file and encrypted secret files match the source revision byte for byte.
The system build dry run also passes. A full build would fetch 3.7 GiB and
build 570 derivations, so it has not been run. Machine activation has not
been performed.
