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

<p><br/></p>

<p align="center">
  <a href="https://github.com/quicknix-dev/quicknix-shell/commits">
    <img src="https://img.shields.io/github/last-commit/quicknix-dev/quicknix-shell?style=for-the-badge&labelColor=0C0D11&color=A8AEFF&logo=git&logoColor=FFFFFF&label=commit" alt="Last commit" />
  </a>
  <a href="https://github.com/quicknix-dev/quicknix-shell/stargazers">
    <img src="https://img.shields.io/github/stars/quicknix-dev/quicknix-shell?style=for-the-badge&labelColor=0C0D11&color=A8AEFF&logo=github&logoColor=FFFFFF" alt="GitHub stars" />
  </a>
  <a href="https://docs.quicknix.dev">
    <img src="https://img.shields.io/badge/docs-A8AEFF?style=for-the-badge&logo=gitbook&logoColor=FFFFFF&labelColor=0C0D11" alt="Documentation" />
  </a>
  <a href="https://discord.quicknix.dev">
    <img src="https://img.shields.io/badge/discord-A8AEFF?style=for-the-badge&labelColor=0C0D11&logo=discord&logoColor=FFFFFF" alt="Discord" />
  </a>
</p>

---

## What is QuickNix?

A beautiful, minimal desktop shell for Wayland that actually gets out of your way. Built on [Quickshell](https://quickshell.outfoxxed.me/) (Qt/QML) with a warm lavender aesthetic that you can easily customize to match your vibe.

**✨ Key Features:**
- 🪟 Native support for Niri, Hyprland, Sway, Scroll, Labwc and MangoWC
- 🎨 Extensive theming with predefined color schemes and automatic color generation from your wallpaper
- 🖼️ Wallpaper management with Wallhaven integration
- 🔔 Notification system with history and Do Not Disturb
- 🖥️ Multi-monitor support
- 🔒 Lock screen
- 🧩 Desktop widgets (clock, media player and more)
- 💡 OSD for volume and brightness
- 🔌 Nearly 100 plugins available ([explore plugins](https://quicknix.dev/plugins/))
- 🪄 Setup wizard for first-time users
- ⚡ Built on Quickshell for performance

---

## Preview

https://github.com/user-attachments/assets/bf46f233-8d66-439a-a1ae-ab0446270f2d

<details>
<summary>Screenshots</summary>

![Dark 1](/Assets/Screenshots/quicknix-dark-1.png)
![Dark 2](/Assets/Screenshots/quicknix-dark-2.png)
![Dark 3](/Assets/Screenshots/quicknix-dark-3.png)

![Light 1](/Assets/Screenshots/quicknix-light-1.png)
![Light 2](/Assets/Screenshots/quicknix-light-2.png)
![Light 3](/Assets/Screenshots/quicknix-light-3.png)

</details>

---

## 📋 Requirements

- Wayland compositor (see supported compositors below)
- Quickshell: [quicknix-qs](https://github.com/quicknix-dev/quicknix-qs)
- Additional dependencies are listed in our [documentation](https://docs.quicknix.dev)

---

## 🚀 Getting Started

**New to QuickNix?**
Check out our comprehensive documentation and installation guide to get up and running!

<p align="center">
  <a href="https://docs.quicknix.dev/getting-started/installation">
    <img src="https://img.shields.io/badge/📖_Installation_Guide-A8AEFF?style=for-the-badge&logoColor=FFFFFF&labelColor=0C0D11" alt="Installation Guide" />
  </a>
  <a href="https://docs.quicknix.dev/getting-started/faq/">
    <img src="https://img.shields.io/badge/❓_FAQ-A8AEFF?style=for-the-badge&logoColor=FFFFFF&labelColor=0C0D11" alt="FAQ" />
  </a>
  <a href="https://discord.quicknix.dev">
    <img src="https://img.shields.io/badge/💬_Get_Help-A8AEFF?style=for-the-badge&logo=discord&logoColor=FFFFFF&labelColor=0C0D11" alt="Discord" />
  </a>
</p>

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

QuickNix provides native support for **Niri**, **Hyprland**, **Sway**, **Scroll**, **Labwc** and **MangoWC**. Other Wayland compositors may work but could require additional configuration for compositor-specific features like workspaces and window management.

---

## Scope

QuickNix is a **desktop shell**, not a full desktop environment. It provides the visual layer that sits on top of your Wayland compositor (bars, panels, notifications, a dock, and widgets) but it intentionally stays within that boundary. Understanding this helps set the right expectations for feature requests.

### What QuickNix does

QuickNix focuses on the things a shell is responsible for: status bar, panels, application launcher, notifications, lock screen, idle management, OSD, theming, wallpapers, desktop widgets, dock, and multi-monitor support.

### What belongs in a plugin

If a feature is useful to some users but not essential to the core shell experience, it's a great candidate for a [plugin](https://quicknix.dev/plugins/). The plugin system is designed to make this easy: plugins can add bar widgets, panels, launcher providers, desktop widgets, and more.

Some examples of features that are better suited as plugins:
- Compositor-specific extras (e.g., Steam overlay for Hyprland)
- Hardware-specific controls (e.g., laptop fan profiles, battery thresholds)
- Third-party service integrations (e.g., smart home controls, Tailscale)
- Niche productivity tools (e.g., Pomodoro timer, RSS reader, Docker manager)
- Alternative visualizations or widgets

If you have an idea that fits this category, consider [building a plugin](https://docs.quicknix.dev/development/guideline) for it!

### What falls outside our scope

Some features go beyond what a desktop shell can or should do. These are typically responsibilities of the compositor, a dedicated application, or the system itself:

- **File management**: use a file manager application
- **Display/login greeter**: this runs before the shell and is managed separately
- **Window management and overview**: workspace switching and window tiling are compositor responsibilities
- **Removable drive mounting**: handled by system services like udisks and desktop applications
- **Screen mirroring/casting**: managed by the compositor or dedicated tools

We appreciate feature suggestions, but if a request falls into this category, it's likely outside what QuickNix can provide. When in doubt, feel free to ask in our [Discord](https://discord.quicknix.dev).

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
