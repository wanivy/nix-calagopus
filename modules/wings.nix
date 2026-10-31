{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.calagopus.wings;
  yaml = pkgs.formats.yaml {};
  configFile = yaml.generate "calagopus-wings.yml" cfg.settings;

  startScript = pkgs.writeShellScript "calagopus-wings-start" ''
    set -o errexit -o nounset

    ${lib.optionalString (cfg.secrets.tokenIdFile != null) ''
      export CALAGOPUS_TOKEN_ID="$(< "$CREDENTIALS_DIRECTORY/token-id")"
    ''}
    ${lib.optionalString (cfg.secrets.tokenFile != null) ''
      export CALAGOPUS_TOKEN="$(< "$CREDENTIALS_DIRECTORY/token")"
    ''}

    exec ${lib.getExe cfg.package} --config ${cfg.runDir}/config.yml --no-setup
  '';
in {
  options.services.calagopus.wings = {
    enable = lib.mkEnableOption "Calagopus Wings";

    package = lib.mkPackageOption pkgs "calagopus-wings" {};

    user = lib.mkOption {
      type = lib.types.str;
      default = "calagopus-wings";
      description = "Host user used for game server files.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "calagopus-wings";
      description = "Host group used for game server files.";
    };

    rootDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/calagopus-wings";
      description = "Root directory for Wings state and server data.";
    };

    logDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/log/calagopus-wings";
      description = "Directory for Wings and server installation logs.";
    };

    tmpDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/cache/calagopus-wings";
      description = "Directory for temporary installation files.";
    };

    runDir = lib.mkOption {
      type = lib.types.path;
      default = "/run/calagopus-wings";
      description = "Directory for runtime files.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the Wings API and SFTP ports in the firewall.";
    };

    secrets = {
      tokenIdFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the Wings token ID.";
      };

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the Wings token.";
      };
    };

    settings = lib.mkOption {
      type = lib.types.submodule {freeformType = yaml.type;};
      default = {};
      description = "Wings configuration written as YAML.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.settings ? uuid && cfg.settings.uuid != "";
        message = "services.calagopus.wings.settings.uuid must be set";
      }
      {
        assertion = cfg.settings ? remote && cfg.settings.remote != "";
        message = "services.calagopus.wings.settings.remote must be set";
      }
      {
        assertion = cfg.secrets.tokenIdFile != null || (cfg.settings ? token_id && cfg.settings.token_id != "");
        message = "services.calagopus.wings.secrets.tokenIdFile or settings.token_id must be set";
      }
      {
        assertion = cfg.secrets.tokenFile != null || (cfg.settings ? token && cfg.settings.token != "");
        message = "services.calagopus.wings.secrets.tokenFile or settings.token must be set";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.rootDir;
        message = "services.calagopus.wings.rootDir must be located below /var/lib";
      }
      {
        assertion = lib.hasPrefix "/var/log/" cfg.logDir;
        message = "services.calagopus.wings.logDir must be located below /var/log";
      }
      {
        assertion = lib.hasPrefix "/var/cache/" cfg.tmpDir;
        message = "services.calagopus.wings.tmpDir must be located below /var/cache";
      }
      {
        assertion = lib.hasPrefix "/run/" cfg.runDir;
        message = "services.calagopus.wings.runDir must be located below /run";
      }
    ];

    services.calagopus.wings.settings = {
      api = {
        host = lib.mkDefault "0.0.0.0";
        port = lib.mkDefault 8080;
      };
      system = {
        root_directory = lib.mkDefault cfg.rootDir;
        log_directory = lib.mkDefault cfg.logDir;
        data = lib.mkDefault "${cfg.rootDir}/volumes";
        archive_directory = lib.mkDefault "${cfg.rootDir}/archives";
        backup_directory = lib.mkDefault "${cfg.rootDir}/backups";
        tmp_directory = lib.mkDefault cfg.tmpDir;
        username = lib.mkDefault cfg.user;
        sftp = {
          bind_address = lib.mkDefault "0.0.0.0";
          bind_port = lib.mkDefault 2022;
        };
        passwd.directory = lib.mkDefault "${cfg.runDir}/etc";
        machine_id.directory = lib.mkDefault "${cfg.runDir}/machine-id";
      };
      docker.network = {
        name = lib.mkDefault "calagopus_nw";
        mode = lib.mkDefault "calagopus_nw";
      };
      ignore_panel_config_updates = lib.mkDefault true;
      ignore_panel_wings_upgrades = lib.mkDefault true;
    };

    virtualisation.docker.enable = true;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      cfg.settings.api.port
      cfg.settings.system.sftp.bind_port
    ];

    environment.systemPackages = [cfg.package];

    users.groups = lib.mkIf (cfg.group == "calagopus-wings") {
      ${cfg.group} = {};
    };

    users.users = lib.mkIf (cfg.user == "calagopus-wings") {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.rootDir;
        extraGroups = ["docker"];
      };
    };

    systemd.services.calagopus-wings = {
      description = "Calagopus Wings";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["docker.service" "network-online.target"];
      requires = ["docker.service"];
      partOf = ["docker.service"];
      restartTriggers = [cfg.package configFile];

      serviceConfig = {
        ExecStartPre = "${pkgs.coreutils}/bin/install -Dm600 ${configFile} ${cfg.runDir}/config.yml";
        ExecStart = startScript;
        LoadCredential =
          lib.optional (cfg.secrets.tokenIdFile != null) "token-id:${cfg.secrets.tokenIdFile}"
          ++ lib.optional (cfg.secrets.tokenFile != null) "token:${cfg.secrets.tokenFile}";
        Restart = "on-failure";
        RestartSec = "5s";
        LimitNOFILE = 4096;
        StateDirectory = lib.removePrefix "/var/lib/" cfg.rootDir;
        LogsDirectory = lib.removePrefix "/var/log/" cfg.logDir;
        CacheDirectory = lib.removePrefix "/var/cache/" cfg.tmpDir;
        RuntimeDirectory = lib.removePrefix "/run/" cfg.runDir;
        ReadWritePaths = [cfg.rootDir cfg.logDir cfg.tmpDir cfg.runDir];
        UMask = "0077";
      };
    };
  };
}
