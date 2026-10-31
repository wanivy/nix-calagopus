# nix-calagopus

Nix packages for [Calagopus](https://calagopus.com):

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

Or add the overlay to another flake:

```nix
{
  inputs.calagopus = {
    url = "github:wanivy/nix-calagopus";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {calagopus, nixpkgs, ...}: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        {nixpkgs.overlays = [calagopus.overlays.default];}
      ];
    };
  };
}
```

The overlay exposes `pkgs.calagopus-panel` and `pkgs.calagopus-wings`.
