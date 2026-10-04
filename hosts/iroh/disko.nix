# SPDX-FileCopyrightText: 2026 First-Non-Interesting-Username
#
# SPDX-License-Identifier: GPL-3.0-or-later
_: {
  disko.devices = {
    disk = {
      root = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-PM991a_NVMe_Samsung_256GB__S660NX1T729293";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                discardPolicy = "both";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = ["-f"];
                subvolumes = {
                  "@" = {
                    mountpoint = "/";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "discard=async"];
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "discard=async"];
                  };
                  "@persist" = {
                    mountpoint = "/persist";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "discard=async"];
                  };
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "discard=async"];
                  };
                };
              };
            };
          };
        };
      };

      ssd = {
        type = "disk";
        device = "/dev/disk/by-id/ata-SSDPR-CX400-512-G2_4S0218458";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/var/lib";
                mountOptions = ["noatime" "errors=remount-ro"];
              };
            };
          };
        };
      };
    };
  };
}
