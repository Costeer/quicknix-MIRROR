# QuickNix Shell

**_quiet by design_**

<p align="center">
  <img src="Assets/quicknix.svg" alt="QuickNix Logo" style="width: 192px" />
</p>

<p align="center">
  <a href="https://docs.quicknix.dev/getting-started/installation">
    <img
      src="https://img.shields.io/badge/🌙_Install_QuickNix-A8AEFF?style=for-the-badge&labelColor=0C0D11"
      alt="Install QuickNix"
      style="height: 50px"
    />
  </a>
</p>

<p> <br/> </p>


---

## What is QuickNix?

A beautiful, minimal desktop shell for Wayland that actually gets out of your way. Built on [Quickshell](https://quickshell.outfoxxed.me/) (Qt/QML) with a warm lavender aesthetic that you can easily customize to match your vibe.

---

## NixOS flakes without Home Manager

The flake exports a NixOS module that can manage both the user service and the shell configuration declaratively.

```nix
{
  inputs.quicknix-shell.url = "github:quicknix-dev/quicknix-shell";

  outputs = { self, nixpkgs, quicknix-shell, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        quicknix-shell.nixosModules.default
        ({ pkgs, ... }: {
          services.quicknix-shell = {
            enable = true;
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

This writes configuration into `/etc/xdg/quicknix` and starts the shell with `QUICKNIX_CONFIG_DIR` pointing there, so Home Manager is not required.

## 🖥️ Wayland Compositors

QuickNix is actively tested on **Niri**, **Hyprland**. Other Wayland compositors may work but could require additional configuration for compositor-specific features like workspaces and window management.

---

## Scope

QuickNix is a **MINIMAL desktop shell**, not a full desktop environment or as featured. It provides the visual layer that sits on top of your Wayland compositor (bars, panels, notifications, a dock, and widgets) but it intentionally stays within that boundary. Understanding this helps set the right expectations for feature requests.

---

## 🤝 Contributing

We welcome contributions of any size - bug fixes, new features, documentation improvements, or custom themes and configs.

**Get involved:**
- **Found a bug?** [Open an issue](https://github.com/quicknix-dev/quicknix-shell/issues/new)
- **Want to code?** Check out our [development guidelines](https://docs.quicknix.dev/development/guideline)
- **Need help?** Join our [Discord](https://discord.quicknix.dev)

---

## 💜 Credits

A heartfelt thank you to our incredible community of [**contributors**](https://github.com/quicknix-dev/quicknix-shell/graphs/contributors). We are immensely grateful for your dedicated participation and the constructive feedback you've provided, which continue to shape and improve our project for everyone.

---

## ☕ Donations

While all donations are greatly appreciated, they are completely voluntary.
Thank you to everyone who supports the project! 💜

<p>
  <a href="https://www.buymeacoffee.com/quicknix">
    <img src="https://img.shields.io/badge/Buy_Me_a_Coffee-A8AEFF?style=for-the-badge&logo=buymeacoffee&logoColor=FFFFFF&labelColor=0C0D11" alt="Buy Me a Coffee">
  </a>
  <a href="https://ko-fi.com/quicknixdev">
    <img src="https://img.shields.io/badge/Ko--fi-A8AEFF?style=for-the-badge&logo=kofi&logoColor=FFFFFF&labelColor=0C0D11" alt="Ko-fi">
  </a>
</p>

---

## 📄 License

MIT License - see [LICENSE](./LICENSE) for details.

---

## ⭐ Star History

<p align="center">
  <a href="https://github.com/quicknix-dev/quicknix-shell/stargazers">
    <img src="https://api.quicknix.dev/stars" alt="Star History" />
  </a>
</p>
