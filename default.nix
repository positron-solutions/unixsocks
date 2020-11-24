{
  source ? import ./nix/sources.nix,
  system ? builtins.currentSystem,
  overlays ? [],
  crossSystem ? null,
}:
let
  rustChannel = "1.45.0";

  # Boilerplate for setting up Nixpkgs with cargo2nix, Rust, and our repo's packages.
  inherit (source) nixpkgs nixpkgs-mozilla cargo2nix;
  pkgs = import nixpkgs {
    inherit system crossSystem;
    overlays =
      let
        rustOverlay = import "${nixpkgs-mozilla}/rust-overlay.nix";
        cargo2nixOverlay = import "${cargo2nix}/overlay";
      in
        [ cargo2nixOverlay rustOverlay repoOverlay ] ++ overlays;
  };

  # Define our Cargo workspace.
  rustPkgs = pkgs.rustBuilder.makePackageSet' {
    inherit rustChannel;
    packageFun = import ./Cargo.nix;
  };

  rust-src = (pkgs.rustChannelOf { channel = rustChannel; }).rust-src;

  repoOverlay = self: super:
    let
      inherit (rustPkgs) workspace;
      unixsocksSrc = self.callPackage self.workspace.unixsocks {};
    in {
      inherit workspace;
      repoPkgs = {
        unixsocks = unixsocksSrc.overrideAttrs(oldAttrs: {
          installPhase = oldAttrs.installPhase or "" +
                         ''
                           rm -r $out/lib
                           rm -r $out/.cargo-info
                         '';
        });
      };
    };
in
pkgs.repoPkgs // rec {
  ci = with builtins; map
    (crate: pkgs.rustBuilder.runTests crate { /* Add `depsBuildBuild` test-only deps here, if any. */ })
    (attrValues rustPkgs.workspace);

  shell = pkgs.mkShell {
    inputsFrom = pkgs.lib.mapAttrsToList (_: crate: crate {}) rustPkgs.noBuild.workspace;
    nativeBuildInputs = with rustPkgs; [ cargo rustc ] ++ [ (import cargo2nix {}).package ];

    RUST_SRC_PATH = "${rust-src}/lib/rustlib/src/rust/src";
  };
}
