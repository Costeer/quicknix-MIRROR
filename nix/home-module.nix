{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.quicknix-shell;
  jsonFormat = pkgs.formats.json { };
  tomlFormat = pkgs.formats.toml { };

  generateJson =
    name: value:
    if lib.isString value then
      pkgs.writeText "quicknix-${name}.json" value
    else if builtins.isPath value || lib.isStorePath value then
      value
    else
      jsonFormat.generate "quicknix-${name}.json" value;

  vicinaeScriptsPackage = pkgs.runCommand "quicknix-vicinae-scripts" { } ''
    install -Dm755 ${../Scripts/vicinae/quicknix-lock} $out/share/vicinae/scripts/quicknix-lock
  '';
in
{
  options.programs.quicknix-shell = {
    enable = lib.mkEnableOption "QuickNix shell configuration";

    systemd.enable = lib.mkEnableOption "QuickNix shell systemd integration";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The quicknix-shell package to use";
    };

    settings = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          bar = {
            position = "bottom";
            floating = true;
            backgroundOpacity = 0.95;
          };
          general = {
            animationSpeed = 1.5;
            radiusRatio = 1.2;
          };
          colorSchemes = {
            darkMode = true;
            useWallpaperColors = true;
          };
        }
      '';
      description = ''
        QuickNix shell configuration settings as an attribute set, string
        or filepath, to be written to ~/.config/quicknix/settings.json.
      '';
    };

    colors = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
         {
           mError = "#dddddd";
           mOnError = "#111111";
           mOnPrimary = "#111111";
           mOnSecondary = "#111111";
           mOnSurface = "#828282";
           mOnSurfaceVariant = "#5d5d5d";
           mOnTertiary = "#111111";
           mOutline = "#3c3c3c";
           mPrimary = "#aaaaaa";
           mSecondary = "#a7a7a7";
           mShadow = "#000000";
           mSurface = "#111111";
           mSurfaceVariant = "#191919";
           mTertiary = "#cccccc";
        }
      '';
      description = ''
        QuickNix shell color configuration as an attribute set, string
        or filepath, to be written to ~/.config/quicknix/colors.json.
      '';
    };

    user-templates = lib.mkOption {
      default = { };
      type =
        with lib.types;
        oneOf [
          tomlFormat.type
          str
          path
        ];
      example = lib.literalExpression ''
        {
          templates = {
            neovim = {
              input_path = "~/.config/quicknix/templates/template.lua";
              output_path = "~/.config/nvim/generated.lua";
              post_hook = "pkill -SIGUSR1 nvim";
            };
          };
        }
      '';
      description = ''
        Template definitions for QuickNix, to be written to ~/.config/quicknix/user-templates.toml.

        This option accepts:
        - a Nix attrset (converted to TOML automatically)
        - a string containing raw TOML
        - a path to an existing TOML file
      '';
    };

    plugins = lib.mkOption {
      type =
        with lib.types;
        oneOf [
          jsonFormat.type
          str
          path
        ];
      default = { };
      example = lib.literalExpression ''
        {
          sources = [
            {
              enabled = true;
              name = "QuickNix Plugins";
              url = "https://github.com/quicknix-dev/quicknix-plugins";
            }
          ];
          states = {
            catwalk = {
              enabled = true;
              sourceUrl = "https://github.com/quicknix-dev/quicknix-plugins";
            };
          };
          version = 2;
        }
      '';
      description = ''
        QuickNix shell plugin configuration as an attribute set, string
        or filepath, to be written to ~/.config/quicknix/plugins.json.
      '';
    };

    pluginSettings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          jsonFormat.type
          str
          path
        ]);
      default = { };
      example = lib.literalExpression ''
        {
          catwalk = {
            minimumThreshold = 25;
            hideBackground = true;
          };
        }
      '';
      description = ''
        Each plugin’s settings as an attribute set, string
        or filepath, to be written to ~/.config/quicknix/plugins/plugin-name/settings.json.
      '';
    };

    vicinaeIntegration.enable = lib.mkEnableOption ''
      Vicinae script commands for controlling QuickNix. This installs a
      QuickNix script command into share/vicinae/scripts so Vicinae can index it
      when Vicinae is installed for the user.
    '';
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.quicknix-shell = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "QuickNix Shell - Wayland desktop shell";
        Documentation = "https://docs.quicknix.dev";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        X-Restart-Triggers =
          lib.optional (cfg.settings != { }) "${config.xdg.configFile."quicknix/settings.json".source}"
          ++ lib.optional (cfg.colors != { }) "${config.xdg.configFile."quicknix/colors.json".source}"
          ++ lib.optional (cfg.plugins != { }) "${config.xdg.configFile."quicknix/plugins.json".source}"
          ++ lib.optional (
            cfg.user-templates != { }
          ) "${config.xdg.configFile."quicknix/user-templates.toml".source}"
          ++ lib.mapAttrsToList (
            name: _: "${config.xdg.configFile."quicknix/plugins/${name}/settings.json".source}"
          ) cfg.pluginSettings;
      };

      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    home.packages = lib.optional (cfg.package != null) cfg.package ++ lib.optional cfg.vicinaeIntegration.enable vicinaeScriptsPackage;

    xdg.dataFile."vicinae/scripts/quicknix-lock" = lib.mkIf cfg.vicinaeIntegration.enable {
      source = ../Scripts/vicinae/quicknix-lock;
      executable = true;
    };

    xdg.configFile = {
      "quicknix/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = generateJson "settings" cfg.settings;
      };
      "quicknix/colors.json" = lib.mkIf (cfg.colors != { }) {
        source = generateJson "colors" cfg.colors;
      };
      "quicknix/plugins.json" = lib.mkIf (cfg.plugins != { }) {
        source = generateJson "plugins" cfg.plugins;
      };
      "quicknix/user-templates.toml" = lib.mkIf (cfg.user-templates != { }) {
        source =
          if lib.isString cfg.user-templates then
            pkgs.writeText "quicknix-user-templates.toml" cfg.user-templates
          else if builtins.isPath cfg.user-templates || lib.isStorePath cfg.user-templates then
            cfg.user-templates
          else
            tomlFormat.generate "quicknix-user-templates.toml" cfg.user-templates;
      };
    }
    // lib.mapAttrs' (
      name: value:
      lib.nameValuePair "quicknix/plugins/${name}/settings.json" {
        source = generateJson "${name}-settings" value;
      }
    ) cfg.pluginSettings;

    assertions = [
      {
        assertion = !cfg.systemd.enable || cfg.package != null;
        message = "quicknix-shell: The package option must not be null when systemd service is enabled.";
      }
    ];
  };
}
