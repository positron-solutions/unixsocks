{
  source ? import ./nix/sources.nix,
  system ? builtins.currentSystem,
  overlays ? [],
  crossSystem ? null,
}:
let
  rustChannel = "1.50.0";

  # Boilerplate for setting up Nixpkgs with cargo2nix, Rust, and our repo's packages.
  inherit (source) nixpkgs rust-overlay cargo2nix;
  pkgs = import nixpkgs {
    inherit system crossSystem;
    overlays =
      let
        rustOverlay = import rust-overlay;
        cargo2nixOverlay = import "${cargo2nix}/overlay";
      in
        [ cargo2nixOverlay rustOverlay ] ++ overlays;
  };

  # Define our Cargo workspace.
  rustPkgs = pkgs.rustBuilder.makePackageSet' {
    inherit rustChannel;
    packageFun = import ./Cargo.nix;
    localPatterns = [ ''^(src|tests|unixsocks|assets|templates)(/.*)?'' ''[^/]*\.(rs|toml)$'' ];
  };
in let
  rust-channel = pkgs.rust-bin.stable."1.50.0";
in rec {
  ci = with builtins; map
    (crate: pkgs.rustBuilder.runTests crate { /* Add `depsBuildBuild` test-only deps here, if any. */ })
    (attrValues rustPkgs.workspace);

  shell = pkgs.mkShell {
    inputsFrom = pkgs.lib.mapAttrsToList (_: crate: crate {}) rustPkgs.noBuild.workspace;
    nativeBuildInputs = with rustPkgs; [ cargo rustc ] ++ [ (import cargo2nix {}).package ];

    RUST_SRC_PATH = "${rustPkgs.rust-src}/lib/rustlib/src/rust/library/";
  };

  package = (rustPkgs.workspace.unixsocks {}).bin;
}
