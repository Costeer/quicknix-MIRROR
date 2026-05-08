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

  idleSettings = lib.filterAttrs (_: value: value != null) {
    enabled = cfg.idle.enabled;
    screenOffTimeout = cfg.idle.screenOffTimeout;
    lockTimeout = cfg.idle.lockTimeout;
    suspendTimeout = cfg.idle.suspendTimeout;
    fadeDuration = cfg.idle.fadeDuration;
  };

  effectiveSettings =
    if idleSettings == { } then
      cfg.settings
    else if builtins.isAttrs cfg.settings then
      lib.recursiveUpdate cfg.settings { idle = idleSettings; }
    else
      cfg.settings;

  configFiles = {
    "settings.json" = generateJson "settings" effectiveSettings;
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
    name: value:
    lib.nameValuePair "plugins/${name}/settings.json" (generateJson "${name}-settings" value)
  ) cfg.pluginSettings;

  etcConfigFiles = lib.mapAttrs' (
    name: source:
    lib.nameValuePair "${lib.removePrefix "/etc/" cfg.configDir}/${name}" {
      inherit source;
    }
  ) configFiles;

  effectivePackage =
    if cfg.extraPackages == [ ] then
      cfg.package
    else
      cfg.package.override { inherit (cfg) extraPackages; };
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

    readOnlyConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether QuickNix should treat the NixOS-managed config directory as read-only.
        When enabled, the shell will not write settings.json or colors.json at runtime.
      '';
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ networkmanager wireplumber ]";
      description = ''
        Extra runtime packages added to the QuickNix wrapper PATH.
        Useful for compositor-specific tools or optional helpers used by widgets.
      '';
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
          idle = {
            enabled = true;
            screenOffTimeout = 600;
            lockTimeout = 660;
            suspendTimeout = 1800;
            fadeDuration = 5;
          };
        }
      '';
    };

    idle = {
      enabled = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = true;
        example = true;
        description = ''
          Whether to enable QuickNix automatic idle handling. This defaults to
          true for NixOS-managed QuickNix services and is written to
          settings.idle.enabled. Set to false to disable automatic idle handling.
        '';
      };

      screenOffTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 600;
        description = ''
          Seconds of inactivity before QuickNix fades out and powers monitors
          off. Set to 0 to disable this stage.
        '';
      };

      lockTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 660;
        description = ''
          Seconds of inactivity before QuickNix fades out and locks the session
          with WlSessionLock. Set to 0 to disable this stage.
        '';
      };

      suspendTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 1800;
        description = ''
          Seconds of inactivity before QuickNix suspends the system. Set to 0 to
          disable this stage.
        '';
      };

      fadeDuration = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        example = 5;
        description = ''
          Seconds for the fade-to-black grace period before an idle action runs.
        '';
      };
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
      {
        assertion = idleSettings == { } || builtins.isAttrs cfg.settings;
        message = "quicknix-shell: services.quicknix-shell.idle.* can only be used when services.quicknix-shell.settings is an attrset, not a raw string or path.";
      }
    ];

    systemd.user.services.quicknix-shell = {
      description = "QuickNix Shell - Wayland desktop shell";
      documentation = [ "https://docs.quicknix.dev" ];
      after = [ cfg.target ];
      partOf = [ cfg.target ];
      wantedBy = [ cfg.target ];
      restartTriggers = [ effectivePackage ] ++ builtins.attrValues configFiles;

      environment = {
        QUICKNIX_CONFIG_DIR = cfg.configDir;
        QUICKNIX_SETTINGS_FILE = "${cfg.configDir}/settings.json";
        QUICKNIX_READ_ONLY_CONFIG = if cfg.readOnlyConfig then "1" else "0";
      };

      serviceConfig = {
        ExecStart = lib.getExe effectivePackage;
        Restart = "on-failure";
      };
    };

    environment.systemPackages = [ effectivePackage ];
    environment.etc = etcConfigFiles;
  };
}
