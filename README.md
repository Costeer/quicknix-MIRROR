# QuickNix Shell

## What is QuickNix?

QuickNix Shell is a personal Wayland desktop shell built with Quickshell. It started as a stripped-down Noctalia Shell variant with the pieces I use, keyboard-oriented interaction, and Nix-first configuration.

> **Nix-only project:** QuickNix is meant to be installed and configured with Nix. The supported installation paths are the NixOS module, the Home Manager module, or the exported Nix package. Non-Nix installation is not a supported target.

---

## Requirements

- Nix with flakes enabled.
- A Wayland compositor. QuickNix is actively tested on **Niri** and **Hyprland**.
- For a full desktop experience, include the helper CLIs your widgets/compositor setup needs, for example `networkmanager`, `wireplumber`, compositor tools, brightness tools, etc. The NixOS module can add these through `extraPackages`.

---

## Flake input

Add QuickNix as a flake input:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quicknix-shell = {
      url = "github:quicknix-dev/quicknix-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

The flake exports:

- `packages.<system>.default`: the `quicknix-shell` package
- `nixosModules.default`: NixOS module
- `homeModules.default`: Home Manager module
- `overlays.default`: overlay exposing `pkgs.quicknix-shell`

---

## NixOS installation

Use the NixOS module when you want the system configuration to manage the QuickNix user service and write declarative configuration under `/etc/xdg/quicknix`.

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

            # Optional: expose QuickNix actions as Vicinae script commands.
            vicinaeIntegration.enable = true;
          };
        })
      ];
    };
  };
}
```

### NixOS options

Important options:

- `services.quicknix-shell.enable`: enable the system-defined user service.
- `services.quicknix-shell.package`: package to run, defaults to the flake package.
- `services.quicknix-shell.target`: systemd user target, default `graphical-session.target`.
- `services.quicknix-shell.configDir`: config directory, default `/etc/xdg/quicknix`.
- `services.quicknix-shell.readOnlyConfig`: default `true`, prevents runtime writes to NixOS-managed config.
- `services.quicknix-shell.settings`: generated `settings.json`.
- `services.quicknix-shell.colors`: generated `colors.json`.
- `services.quicknix-shell.plugins`: generated `plugins.json`.
- `services.quicknix-shell.pluginSettings`: generated per-plugin settings files.
- `services.quicknix-shell.extraPackages`: extra runtime CLIs added to the QuickNix wrapper `PATH`.
- `services.quicknix-shell.vicinaeIntegration.enable`: install QuickNix Vicinae script commands, such as “Lock Session” and “Lock and Hibernate”.

### NixOS idle and power options

The NixOS module exposes common idle settings directly and writes them into `settings.idle`:

```nix
services.quicknix-shell = {
  enable = true;

  idle = {
    enabled = true;

    # Seconds of inactivity before turning monitors off. 0 disables this stage.
    screenOffTimeout = 600;

    # Seconds of inactivity before locking the session. 0 disables this stage.
    lockTimeout = 660;

    # Seconds of inactivity before suspending. 0 disables this stage.
    suspendTimeout = 1800;

    # Seconds of inactivity before hibernating. 0 disables this stage.
    hibernateTimeout = 3600;

    # Seconds after laptop lid close before hibernating. 0 disables this stage.
    # Lid close still locks immediately and turns the screen off first.
    lidHibernateTimeout = 900;

    # Disable caffeine / idle inhibition when the lid closes.
    disableCaffeineOnLidClose = true;

    # Fade-to-black grace period before idle actions run.
    fadeDuration = 5;
  };
};
```

Recommended ordering:

```text
screenOffTimeout < lockTimeout < suspendTimeout < hibernateTimeout
```

For laptops, `lidHibernateTimeout` can be much shorter than normal hibernation, for example 300 to 900 seconds. `disableCaffeineOnLidClose` defaults to `true`, so closing the lid allows lock, screen-off, and hibernation to proceed even if caffeine was enabled.

### NixOS integration contract

The NixOS module sets these environment variables for the service:

- `QUICKNIX_CONFIG_DIR`: declarative config directory, default `/etc/xdg/quicknix`
- `QUICKNIX_SETTINGS_FILE`: settings file, default `/etc/xdg/quicknix/settings.json`
- `QUICKNIX_READ_ONLY_CONFIG`: `1` by default; prevents runtime writes to NixOS-managed config

The NixOS module defines a user service at the system level, so it is available to graphical users on the host. Use the Home Manager module if you need strictly per-user ownership of the service and mutable `~/.config/quicknix` files.

---

## Home Manager installation

Use the Home Manager module when you want QuickNix to be owned entirely by a user and configured under `~/.config/quicknix`.

```nix
{
  inputs.quicknix-shell = {
    url = "github:quicknix-dev/quicknix-shell";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, quicknix-shell, ... }: {
    homeConfigurations."costeer" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        quicknix-shell.homeModules.default
        ({ pkgs, ... }: {
          programs.quicknix-shell = {
            enable = true;
            systemd.enable = true;

            settings = {
              bar.position = "bottom";
              general.animationSpeed = 1.2;

              idle = {
                enabled = true;
                screenOffTimeout = 600;
                lockTimeout = 660;
                suspendTimeout = 1800;
                hibernateTimeout = 3600;
                lidHibernateTimeout = 900;
                fadeDuration = 5;
              };
            };

            colors = {
              mPrimary = "#a8aeff";
            };

            plugins = {
              sources = [ ];
              states = { };
              version = 2;
            };

            pluginSettings.example = {
              enabled = true;
            };

            # Optional: install QuickNix Vicinae scripts into the user's data dir.
            vicinaeIntegration.enable = true;
          };
        })
      ];
    };
  };
}
```

### Home Manager options

Important options:

- `programs.quicknix-shell.enable`: install/manage QuickNix for the user.
- `programs.quicknix-shell.systemd.enable`: create a user systemd service.
- `programs.quicknix-shell.package`: package to install, defaults to the flake package.
- `programs.quicknix-shell.settings`: generated `~/.config/quicknix/settings.json`.
- `programs.quicknix-shell.colors`: generated `~/.config/quicknix/colors.json`.
- `programs.quicknix-shell.plugins`: generated `~/.config/quicknix/plugins.json`.
- `programs.quicknix-shell.pluginSettings`: generated per-plugin settings files.
- `programs.quicknix-shell.user-templates`: generated `user-templates.toml`.
- `programs.quicknix-shell.vicinaeIntegration.enable`: install QuickNix Vicinae script commands, such as “Lock Session” and “Lock and Hibernate”.

Home Manager does not currently expose a separate `programs.quicknix-shell.idle` convenience option. Put idle settings under `programs.quicknix-shell.settings.idle` as shown above.

---

## Using the package directly

If you only want the package, add the overlay or reference the flake package directly:

```nix
environment.systemPackages = [
  inputs.quicknix-shell.packages.${pkgs.stdenv.hostPlatform.system}.default
];
```

Then run:

```sh
quicknix-shell
```

For declarative desktop sessions, prefer the NixOS or Home Manager module so the service and config files are managed consistently.

---

## Runtime commands and troubleshooting

Check service status:

```sh
systemctl --user status quicknix-shell
journalctl --user -u quicknix-shell -b
```

Lock the session on demand:

```sh
quicknix-lock
# or from a checkout:
./Scripts/quicknix-lock
```

Lock and hibernate on demand:

```sh
quicknix-lock-hibernate
# or from a checkout:
./Scripts/quicknix-lock-hibernate
```

Test the lockscreen immediately, without waiting for idle:

```sh
./Scripts/test-lockscreen
# or, when installed:
QUICKNIX_TEST_LOCKSCREEN=1 quicknix-shell
```

When testing from a checkout and you want to force the local tree rather than an installed package:

```sh
cd /path/to/quickNix
QUICKNIX_TEST_LOCKSCREEN=1 QS_CONFIG_PATH="$PWD" qs
```

---

## Wayland compositors

QuickNix is actively tested on **Niri** and **Hyprland**. Other Wayland compositors may work but could require additional configuration for compositor-specific features like workspaces, monitor power control, and window management.
