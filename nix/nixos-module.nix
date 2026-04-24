{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.quicknix-shell;
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

  generateToml =
    name: value:
    if lib.isString value then
      pkgs.writeText "quicknix-${name}.toml" value
    else if builtins.isPath value || lib.isStorePath value then
      value
    else
      tomlFormat.generate "quicknix-${name}.toml" value;

  configFiles =
    lib.optionalAttrs (cfg.settings != { }) {
      "settings.json" = generateJson "settings" cfg.settings;
    }
    // lib.optionalAttrs (cfg.colors != { }) {
      "colors.json" = generateJson "colors" cfg.colors;
    }
    // lib.optionalAttrs (cfg.plugins != { }) {
      "plugins.json" = generateJson "plugins" cfg.plugins;
    }
    // lib.optionalAttrs (cfg.user-templates != { }) {
      "user-templates.toml" = generateToml "user-templates" cfg.user-templates;
    }
    // lib.mapAttrs' (
      name: value: lib.nameValuePair "plugins/${name}/settings.json" (generateJson "${name}-settings" value)
    ) cfg.pluginSettings;

  etcConfigFiles = lib.mapAttrs' (
    name: source:
    lib.nameValuePair "${lib.removePrefix "/etc/" cfg.configDir}/${name}" {
      inherit source;
    }
  ) configFiles;
in
{
  options.services.quicknix-shell = {
    enable = lib.mkEnableOption "QuickNix shell systemd service";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The quicknix-shell package to use";
    };

    target = lib.mkOption {
      type = lib.types.str;
      default = "graphical-session.target";
      example = "hyprland-session.target";
      description = "The systemd target for the quicknix-shell service.";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/etc/xdg/quicknix";
      example = "/etc/xdg/quicknix";
      description = ''
        Absolute configuration directory exposed to QuickNix through QUICKNIX_CONFIG_DIR.
        This is typically managed declaratively by NixOS and is read-only at runtime.
      '';
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
      description = ''
        QuickNix settings.json content managed by NixOS.
      '';
      example = lib.literalExpression ''
        {
          general.animationSpeed = 1.2;
          bar.position = "bottom";
        }
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
      description = "QuickNix colors.json content managed by NixOS.";
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
      description = "QuickNix user-templates.toml content managed by NixOS.";
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
      description = "QuickNix plugins.json content managed by NixOS.";
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
      description = ''
        Plugin settings managed by NixOS. Each entry is written to
        plugins/<name>/settings.json inside the configured configDir.
      '';
      example = lib.literalExpression ''
        {
          catwalk = {
            minimumThreshold = 25;
            hideBackground = true;
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/etc/" cfg.configDir;
        message = "quicknix-shell: services.quicknix-shell.configDir must live under /etc for environment.etc deployment.";
      }
    ];

    systemd.user.services.quicknix-shell = {
      description = "QuickNix Shell - Wayland desktop shell";
      documentation = [ "https://docs.quicknix.dev" ];
      after = [ cfg.target ];
      partOf = [ cfg.target ];
      wantedBy = [ cfg.target ];
      restartTriggers = [ cfg.package ] ++ builtins.attrValues configFiles;

      environment = {
        PATH = lib.mkForce null;
        QUICKNIX_CONFIG_DIR = cfg.configDir;
        QUICKNIX_SETTINGS_FILE = "${cfg.configDir}/settings.json";
      };

      serviceConfig = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
      };
    };

    environment.systemPackages = [ cfg.package ];
    environment.etc = etcConfigFiles;
  };
}
