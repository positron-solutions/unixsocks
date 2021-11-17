{
  inputs = {
    cargo2nix.url = "github:cargo2nix/cargo2nix/";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-21.05";
  };

  outputs = { self, nixpkgs, cargo2nix, flake-utils, rust-overlay, ... }:

    # Build the output set for each default system and map system sets into
    # attributes, resulting in paths such as:
    # nix build .#packages.x86_64-linux.<name>
    flake-utils.lib.eachDefaultSystem (system:

      # let-in expressions, very similar to Rust's let bindings.  These names
      # are used to express the output but not themselves paths in the output.
      let

        # create nixpkgs that contains rustBuilder from cargo2nix overlay
        pkgs = import nixpkgs {
          inherit system;
          overlays = [(import "${cargo2nix}/overlay")
                      rust-overlay.overlay];
        };

        # create the workspace & dependencies package set
        rustPkgs = pkgs.rustBuilder.makePackageSet' {
          rustChannel = "1.56.1";
          packageFun = import ./Cargo.nix;
          # packageOverrides = pkgs: pkgs.rustBuilder.overrides.all; # Implied, if not specified
        };

        # The workspace defines a development shell with all of the dependencies
        # and environment settings necessary for a regular `cargo build`
        workspaceShell = rustPkgs.workspaceShell {};

      in rec {
        # this is the output (recursive) set (expressed for each system)

        # nix develop
        devShell = workspaceShell;

        # the packages in `nix build .#packages.<system>.<name>`
        packages = {
          # nix build .#unixsocks
          # nix build .#packages.x86_64-linux.unixsocks
          unixsocks = (rustPkgs.workspace.unixsocks {}).bin;
        };

        # nix run github:positron-solutions/unixsocks
        defaultApp = { type = "app"; program = "${defaultPackage}/bin/unixsocks";};

        # nix build
        defaultPackage = packages.unixsocks;
      }
    );
}
