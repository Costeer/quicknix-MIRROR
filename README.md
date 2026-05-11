# QuickNix Shell

## What is QuickNix?

A copy of Noctalia Shell but i removed all the things i dont need and added keyboard support 

---

## NixOS flakes without Home Manager

The flake exports a NixOS module that can manage both the user service and the shell configuration declaratively.

```nix
{
  inputs.quicknix-shell = {
    url = "github:quicknix-dev/quicknix-shell";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, quicknix-shell, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        quicknix-shell.nixosModules.default
        ({ pkgs, ... }: {
          services.quicknix-shell = {
            enable = true;

            # The NixOS module writes declarative config to /etc/xdg/quicknix.
            # Runtime writes are disabled by default so the shell does not try to
            # modify read-only NixOS-managed files.
            readOnlyConfig = true;

            # Optional: add helper CLIs used by widgets or compositor integration.
            extraPackages = with pkgs; [
              networkmanager
              wireplumber
            ];

            settings = {
              bar.position = "bottom";
              general.animationSpeed = 1.2;
            };
            colors = {
              mPrimary = "#a8aeff";
            };
            pluginSettings.example = {
              enabled = true;
            };
          };
        })
      ];
    };
  };
}
```

This writes configuration into `/etc/xdg/quicknix` and starts a `systemd.user` service with `QUICKNIX_CONFIG_DIR` pointing there, so Home Manager is not required.

### NixOS integration contract

The NixOS module sets these environment variables for the service:

- `QUICKNIX_CONFIG_DIR`: declarative config directory, default `/etc/xdg/quicknix`
- `QUICKNIX_SETTINGS_FILE`: settings file, default `/etc/xdg/quicknix/settings.json`
- `QUICKNIX_READ_ONLY_CONFIG`: `1` by default; prevents runtime writes to NixOS-managed config

Useful options:

- `services.quicknix-shell.enable`: enable the user service
- `services.quicknix-shell.target`: systemd user target, default `graphical-session.target`
- `services.quicknix-shell.settings`: generated `settings.json`
- `services.quicknix-shell.colors`: generated `colors.json`
- `services.quicknix-shell.plugins`: generated `plugins.json`
- `services.quicknix-shell.pluginSettings`: generated plugin settings
- `services.quicknix-shell.extraPackages`: extra runtime CLIs added to the wrapper `PATH`

Troubleshooting:

```sh
systemctl --user status quicknix-shell
journalctl --user -u quicknix-shell -b
```

Test the lockscreen immediately, without waiting for idle:

```sh
./Scripts/test-lockscreen
# or, when installed:
QUICKNIX_TEST_LOCKSCREEN=1 quicknix-shell
```

The NixOS module defines a user service at the system level, so it is available to graphical users on the host. Use the Home Manager module if you need strictly per-user ownership of the service and mutable `~/.config/quicknix` files.

## Wayland Compositors

QuickNix is actively tested on **Niri**, **Hyprland**. Other Wayland compositors may work but could require additional configuration for compositor-specific features like workspaces and window management.

---
