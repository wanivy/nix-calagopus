# nix-calagopus

Nix packages and NixOS modules for [Calagopus](https://calagopus.com):

- `calagopus-panel` — the web panel;
- `calagopus-wings` — the server control plane.

Only `x86_64-linux` is supported because the upstream releases are native
x86_64 binaries.

## Usage

Run a package directly:

```console
nix run github:wanivy/nix-calagopus#calagopus-panel -- --version
nix run github:wanivy/nix-calagopus#calagopus-wings -- --version
```

## NixOS modules

Add the module and overlay to another flake:

```nix
{
  inputs.calagopus = {
    url = "github:wanivy/nix-calagopus";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {calagopus, nixpkgs, ...}: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        calagopus.nixosModules.default
        {nixpkgs.overlays = [calagopus.overlays.default];}
      ];
    };
  };
}
```

The overlay exposes `pkgs.calagopus-panel` and `pkgs.calagopus-wings`. The
individual modules are also exported as `nixosModules.panel` and
`nixosModules.wings`.

### Panel

The default configuration creates local PostgreSQL and Redis instances. Keep
the encryption key outside the Nix store:

```nix
services.calagopus.panel = {
  enable = true;
  app = {
    url = "https://panel.example.com";
    encryptionKeyFile = "/run/secrets/calagopus-panel-key";
  };
};
```

For external services, disable local creation and provide URLs. URL files are
loaded through systemd credentials and are suitable for passwords:

```nix
services.calagopus.panel = {
  enable = true;
  app = {
    url = "https://panel.example.com";
    encryptionKeyFile = "/run/secrets/calagopus-panel-key";
  };
  database = {
    createLocally = false;
    urlFile = "/run/secrets/calagopus-database-url";
  };
  redis = {
    createLocally = false;
    urlFile = "/run/secrets/calagopus-redis-url";
  };
};
```

The panel listens on `127.0.0.1:8000` by default, ready for a reverse proxy.
Use `environment` for additional variables supported by Calagopus.

### Wings

`settings` is converted to the Wings YAML configuration. Tokens are loaded
through systemd credentials and never copied into the Nix store:

```nix
services.calagopus.wings = {
  enable = true;
  openFirewall = true;
  secrets = {
    tokenIdFile = "/run/secrets/calagopus-wings-token-id";
    tokenFile = "/run/secrets/calagopus-wings-token";
  };
  settings = {
    uuid = "00000000-0000-0000-0000-000000000000";
    remote = "https://panel.example.com";
    api.ssl = {
      enabled = true;
      cert = "/var/lib/calagopus-wings/certificates/node.example.com.crt";
      key = "/var/lib/calagopus-wings/certificates/node.example.com.key";
    };
  };
};
```

The module enables Docker and supplies defaults for the data, log, cache,
runtime, API (`8080`), and SFTP (`2022`) paths and ports. Any default can be
overridden under `settings`.
