{
  description = "Nix packages for Calagopus Panel and Wings";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {
    self,
    nixpkgs,
  }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    nixosModules = {
      panel = ./modules/panel.nix;
      wings = ./modules/wings.nix;
      default = {
        imports = [
          self.nixosModules.panel
          self.nixosModules.wings
        ];
      };
    };

    overlays.default = final: _prev: {
      calagopus-panel = final.callPackage ./packages/panel.nix {};
      calagopus-wings = final.callPackage ./packages/wings.nix {};
    };

    packages = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
      in {
        inherit (pkgs) calagopus-panel calagopus-wings;
        default = pkgs.calagopus-panel;
      }
    );

    checks = forAllSystems (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [self.overlays.default];
        };
        moduleTest = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            {
              boot.isContainer = true;
              networking.hostName = "calagopus-module-test";
              nixpkgs.overlays = [self.overlays.default];
              system.stateVersion = "25.11";

              services.calagopus = {
                panel = {
                  enable = true;
                  app = {
                    url = "https://panel.example.com";
                    encryptionKeyFile = "/run/secrets/calagopus-panel-key";
                  };
                };
                wings = {
                  enable = true;
                  secrets = {
                    tokenIdFile = "/run/secrets/calagopus-wings-token-id";
                    tokenFile = "/run/secrets/calagopus-wings-token";
                  };
                  settings = {
                    uuid = "00000000-0000-0000-0000-000000000000";
                    remote = "https://panel.example.com";
                  };
                };
              };
            }
          ];
        };
      in {
        inherit (self.packages.${system}) calagopus-panel calagopus-wings;

        module-evaluation =
          pkgs.runCommand "calagopus-module-evaluation" {
            panelUnit = moduleTest.config.systemd.services.calagopus-panel.serviceConfig.ExecStart;
            testedSystem = builtins.unsafeDiscardStringContext moduleTest.config.system.build.toplevel.drvPath;
            wingsUnit = moduleTest.config.systemd.services.calagopus-wings.serviceConfig.ExecStart;
          } ''
            touch "$out"
          '';
      }
    );

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
