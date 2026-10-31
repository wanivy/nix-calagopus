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

    checks = forAllSystems (system: {
      inherit (self.packages.${system}) calagopus-panel calagopus-wings;
    });

    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
