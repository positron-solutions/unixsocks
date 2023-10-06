{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=release-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    cargo2nix = {
      url = "github:cargo2nix/cargo2nix/release-0.11.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };

  outputs = inputs: with inputs;

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
          overlays = [ cargo2nix.overlays.default ];
        };

        # create the workspace & dependencies package set
        rustPkgs = pkgs.rustBuilder.makePackageSet {
          packageFun = import ./Cargo.nix;
          rustVersion = "1.72.1";
        };

        # The workspace defines a development shell with all of the dependencies
        # and environment settings necessary for a regular `cargo build`
        workspaceShell = rustPkgs.workspaceShell {
          # This adds cargo2nix to the project shell via the cargo2nix flake
          packages = [ cargo2nix.packages."${system}".cargo2nix ];
        };

      in rec {
        # this is the output (recursive) set (expressed for each system)

        devShells = {
          default = workspaceShell; # nix develop
        };

        # the packages in `nix build .#packages.<system>.<name>`
        packages = {
          # nix build .#unixsocks
          # nix build .#packages.x86_64-linux.unixsocks
          unixsocks = (rustPkgs.workspace.unixsocks {}).bin;
          # nix build
          default = packages.unixsocks;
        };

        # nix run github:positron-solutions/unixsocks
        apps = rec {
          unixsocks = { type = "app"; program = "${packages.default}/bin/unixsocks"; };
          default = unixsocks;
        };
      }
    );
}
