{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.calagopus.panel;

  localDatabaseUrl = "postgresql://${cfg.database.user}@localhost/${cfg.database.name}?host=/run/postgresql";
  localRedisUrl = "redis://${cfg.redis.host}:${toString cfg.redis.port}/${toString cfg.redis.database}";

  environment =
    {
      APP_DEBUG = lib.boolToString cfg.app.debug;
      APP_PRIMARY = lib.boolToString cfg.app.primary;
      APP_URL = cfg.app.url;
      BIND = cfg.bindAddress;
      DATABASE_MIGRATE = lib.boolToString cfg.database.migrate;
      PORT = toString cfg.port;
      REDIS_KEY_PREFIX = cfg.redis.keyPrefix;
      REDIS_MODE = cfg.redis.mode;
    }
    // lib.optionalAttrs (cfg.database.urlFile == null && (cfg.database.createLocally || cfg.database.url != null)) {
      DATABASE_URL =
        if cfg.database.createLocally
        then localDatabaseUrl
        else cfg.database.url;
    }
    // lib.optionalAttrs (cfg.redis.urlFile == null && (cfg.redis.createLocally || cfg.redis.url != null)) {
      REDIS_URL =
        if cfg.redis.createLocally
        then localRedisUrl
        else cfg.redis.url;
    }
    // cfg.environment;

  startScript = pkgs.writeShellScript "calagopus-panel-start" ''
    set -o errexit -o nounset

    export APP_ENCRYPTION_KEY="$(< "$CREDENTIALS_DIRECTORY/app-encryption-key")"
    ${lib.optionalString (cfg.database.urlFile != null) ''
      export DATABASE_URL="$(< "$CREDENTIALS_DIRECTORY/database-url")"
    ''}
    ${lib.optionalString (cfg.redis.urlFile != null) ''
      export REDIS_URL="$(< "$CREDENTIALS_DIRECTORY/redis-url")"
    ''}

    exec ${lib.getExe cfg.package} "$@"
  '';
in {
  options.services.calagopus.panel = {
    enable = lib.mkEnableOption "Calagopus Panel";

    package = lib.mkPackageOption pkgs "calagopus-panel" {};

    user = lib.mkOption {
      type = lib.types.str;
      default = "calagopus-panel";
      description = "User account under which the panel runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "calagopus-panel";
      description = "Group under which the panel runs.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/calagopus-panel";
      description = "Persistent state directory for the panel.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address on which the panel listens.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port on which the panel listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open the panel port in the firewall.";
    };

    app = {
      url = lib.mkOption {
        type = lib.types.str;
        example = "https://panel.example.com";
        description = "Public URL of the panel.";
      };

      encryptionKeyFile = lib.mkOption {
        type = lib.types.path;
        example = "/run/secrets/calagopus-panel-key";
        description = "File containing the panel encryption key.";
      };

      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to enable debug logging.";
      };

      primary = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether this instance is responsible for background tasks.";
      };
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create and use a local PostgreSQL database.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = cfg.database.user;
        defaultText = lib.literalExpression "config.services.calagopus.panel.database.user";
        description = "Name of the local PostgreSQL database.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = cfg.user;
        defaultText = lib.literalExpression "config.services.calagopus.panel.user";
        description = "Owner of the local PostgreSQL database.";
      };

      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "postgresql://calagopus:password@db.example.com/calagopus";
        description = "PostgreSQL URL for an external database. This value is stored in the Nix store; prefer urlFile for URLs containing a password.";
      };

      urlFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the PostgreSQL URL for an external database.";
      };

      migrate = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to run database migrations when the panel starts.";
      };
    };

    redis = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to create and use a local Redis instance.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "calagopus-panel";
        description = "Name of the local Redis server.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Address of the local Redis server.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6380;
        description = "Port of the local Redis server.";
      };

      database = lib.mkOption {
        type = lib.types.ints.between 0 15;
        default = 0;
        description = "Redis database number.";
      };

      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "redis://redis.example.com:6379/0";
        description = "URL of an external Redis server. This value is stored in the Nix store; prefer urlFile for URLs containing a password.";
      };

      urlFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "File containing the URL of an external Redis server.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "redis";
        description = "Calagopus Redis mode.";
      };

      keyPrefix = lib.mkOption {
        type = lib.types.str;
        default = "calagopus";
        description = "Prefix used for keys stored in Redis.";
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {APP_REQUEST_LOG_LIMIT = "250";};
      description = "Additional environment variables. These override generated values.";
    };

    environmentFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Environment files read by systemd. Prefix an optional file with '-'.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.database.createLocally || cfg.database.url != null || cfg.database.urlFile != null;
        message = "services.calagopus.panel.database.url or urlFile must be set when createLocally is false";
      }
      {
        assertion = !(cfg.database.url != null && cfg.database.urlFile != null);
        message = "services.calagopus.panel.database.url and urlFile are mutually exclusive";
      }
      {
        assertion = cfg.redis.createLocally || cfg.redis.url != null || cfg.redis.urlFile != null;
        message = "services.calagopus.panel.redis.url or urlFile must be set when createLocally is false";
      }
      {
        assertion = !(cfg.redis.url != null && cfg.redis.urlFile != null);
        message = "services.calagopus.panel.redis.url and urlFile are mutually exclusive";
      }
      {
        assertion = lib.hasPrefix "/var/lib/" cfg.dataDir;
        message = "services.calagopus.panel.dataDir must be located below /var/lib";
      }
      {
        assertion = !cfg.database.createLocally || (cfg.database.user == cfg.user && cfg.database.name == cfg.database.user);
        message = "services.calagopus.panel.database.name, database.user, and user must match when createLocally is true (database ownership and PostgreSQL peer authentication)";
      }
    ];

    services.postgresql = lib.mkIf cfg.database.createLocally {
      enable = true;
      ensureDatabases = [cfg.database.name];
      ensureUsers = [
        {
          name = cfg.database.user;
          ensureDBOwnership = true;
        }
      ];
    };

    services.redis.servers.${cfg.redis.name} = lib.mkIf cfg.redis.createLocally {
      enable = true;
      bind = cfg.redis.host;
      port = cfg.redis.port;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [cfg.port];

    environment.systemPackages = [cfg.package];

    users.groups = lib.mkIf (cfg.group == "calagopus-panel") {
      ${cfg.group} = {};
    };

    users.users = lib.mkIf (cfg.user == "calagopus-panel") {
      ${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
      };
    };

    systemd.services.calagopus-panel = {
      description = "Calagopus Panel";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after =
        ["network-online.target"]
        ++ lib.optional cfg.database.createLocally "postgresql.service"
        ++ lib.optional cfg.redis.createLocally "redis-${cfg.redis.name}.service";
      requires =
        lib.optional cfg.database.createLocally "postgresql.service"
        ++ lib.optional cfg.redis.createLocally "redis-${cfg.redis.name}.service";
      environment = environment;
      restartTriggers = [cfg.package];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = startScript;
        EnvironmentFile = cfg.environmentFiles;
        LoadCredential =
          ["app-encryption-key:${cfg.app.encryptionKeyFile}"]
          ++ lib.optional (cfg.database.urlFile != null) "database-url:${cfg.database.urlFile}"
          ++ lib.optional (cfg.redis.urlFile != null) "redis-url:${cfg.redis.urlFile}";
        Restart = "on-failure";
        RestartSec = "5s";
        StateDirectory = lib.removePrefix "/var/lib/" cfg.dataDir;
        WorkingDirectory = cfg.dataDir;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };
  };
}
