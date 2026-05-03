# Plan: add QuickNix Shell to a NixOS configuration

This plan is for an agent working in a separate NixOS config repo that needs to integrate this shell declaratively.

## Goal

Add `quicknix-shell` as a flake input, import its NixOS module, enable the user service, and provide an initial declarative QuickNix config.

## What this repo already provides

Relevant files in this repo:

- `flake.nix`
  - exports `nixosModules.default`
  - exports `homeModules.default`
  - exports `packages.<system>.default`
- `nix/nixos-module.nix`
  - defines `services.quicknix-shell.*`
  - installs the package into `environment.systemPackages`
  - writes config into `/etc/xdg/quicknix` by default
  - starts a `systemd.user` service named `quicknix-shell`
- `nix/package.nix`
  - wraps the shell executable
  - sets `QS_CONFIG_PATH` to the packaged shell assets
  - injects runtime dependencies into `PATH`

## Recommended integration approach

Use the exported NixOS module from this flake.

This is the simplest path because it:

1. installs the package
2. deploys config files under `/etc/xdg/quicknix`
3. sets `QUICKNIX_CONFIG_DIR`
4. starts the shell as a user systemd service

## Steps in the NixOS config repo

### 1. Add the flake input

Add an input similar to:

```nix
inputs.quicknix-shell.url = "github:quicknix-dev/quicknix-shell";
```

If the target repo pins `nixpkgs`, make `quicknix-shell.inputs.nixpkgs.follows = "nixpkgs"` if appropriate.

Example:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    quicknix-shell = {
      url = "github:quicknix-dev/quicknix-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

### 2. Import the NixOS module

In the relevant host config, add:

```nix
modules = [
  quicknix-shell.nixosModules.default
  ./hosts/my-host.nix
];
```

### 3. Enable the service

Add a minimal configuration:

```nix
{
  services.quicknix-shell.enable = true;
}
```

That is enough to install the package and create the user service.

### 4. Add initial declarative QuickNix settings

Start with a small config so the shell can boot with known values.

Example:

```nix
{
  services.quicknix-shell = {
    enable = true;

    settings = {
      bar.position = "bottom";
      general.animationSpeed = 1.0;
    };

    colors = {
      mPrimary = "#a8aeff";
    };

    pluginSettings = {
      example = {
        enabled = true;
      };
    };
  };
}
```

## Available NixOS options

The module exposes:

- `services.quicknix-shell.enable`
- `services.quicknix-shell.package`
- `services.quicknix-shell.target`
- `services.quicknix-shell.configDir`
- `services.quicknix-shell.settings`
- `services.quicknix-shell.colors`
- `services.quicknix-shell.user-templates`
- `services.quicknix-shell.plugins`
- `services.quicknix-shell.pluginSettings`

## Important behavior to preserve

### Config directory

Default config directory:

```nix
services.quicknix-shell.configDir = "/etc/xdg/quicknix";
```

The module asserts that `configDir` must stay under `/etc/`, because it uses `environment.etc` to deploy files.

Do not move this to a home-directory path when using the NixOS module.

### Systemd target

Default target:

```nix
services.quicknix-shell.target = "graphical-session.target";
```

If the host uses a compositor-specific session target, it may be better to bind QuickNix to that instead, for example:

```nix
services.quicknix-shell.target = "hyprland-session.target";
```

Possible follow-up task for the integration agent: inspect the target system’s compositor/session setup and choose the correct target.

## Integration checklist

The agent should verify all of the following in the target NixOS repo:

1. QuickNix flake input is added
2. `quicknix-shell.nixosModules.default` is imported
3. `services.quicknix-shell.enable = true` is set
4. A session target is chosen that actually exists on the machine
5. Initial `settings` are present
6. Optional `colors`, `plugins`, and `pluginSettings` are present if needed
7. The host already has a supported Wayland compositor configured
8. Rebuild succeeds
9. The user service starts in the graphical session

## Validation commands for the target machine

After `nixos-rebuild switch`, validate with:

```bash
systemctl --user status quicknix-shell
journalctl --user -u quicknix-shell -b
```

Also check that generated config files exist conceptually under:

- `/etc/xdg/quicknix/settings.json`
- `/etc/xdg/quicknix/colors.json`
- `/etc/xdg/quicknix/plugins.json`
- `/etc/xdg/quicknix/plugins/<name>/settings.json`

## Known assumptions

This shell expects:

- Wayland
- Quickshell runtime via the packaged dependency chain
- a supported compositor such as Niri, Hyprland, Sway, Scroll, Labwc, or MangoWC

The module does **not** configure the compositor for the user. That remains the responsibility of the target NixOS config.

## Suggested implementation shape in the target repo

A clean layout would be:

- flake input in `flake.nix`
- module import in the host or desktop profile module
- QuickNix settings in a dedicated module such as `modules/desktops/quicknix.nix`

Example split:

```nix
# modules/desktops/quicknix.nix
{ quicknix-shell, ... }:
{
  imports = [ quicknix-shell.nixosModules.default ];

  services.quicknix-shell = {
    enable = true;
    target = "graphical-session.target";

    settings = {
      bar.position = "bottom";
      general.animationSpeed = 1.0;
    };
  };
}
```

## If customization is needed

The module accepts attrsets, raw strings, or file paths for:

- `settings`
- `colors`
- `plugins`
- `user-templates`
- each entry in `pluginSettings`

So the integration agent can either:

1. keep everything inline in Nix, or
2. generate/use checked-in JSON/TOML files and pass paths

Prefer inline Nix attrsets for a first integration unless the target repo already stores large JSON/TOML blobs separately.

## Minimal success criteria

The task is complete when:

- the NixOS config builds
- the `quicknix-shell` package is installed
- the user service is enabled and starts
- QuickNix receives config from `/etc/xdg/quicknix`
- the shell appears in the Wayland session without requiring Home Manager
