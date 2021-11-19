# Unixsocks

Want to ssh over a tor service but `socat` doesn't accept unix addresses and
you've configured your tor client to serve local clients over a unix socket?
This is your tool!

## Usage

If your tor service is exposing a unix socket to your user at
`/run/tor/behind-nat/users.sock` and has the tor address
`a2bg8me3awc9x8zb.onion` which accepts connections on `700` and forwards those
to a remote ssh server started on demand, your ssh config in `~/.ssh/config`
will contain entries like this:

```
Host behind-nat-ssh-server
    Hostname a2bg8me3awc9x8zb.onion
    ProxyCommand unixsocks --port 700 --socket-path /run/tor/behind-nat/users.sock --remote-host a2bg8me3awc9x8zb.onion
    IdentityFile ~/.ssh/behind-nat-ssh-server-git
    User git

Host behind-nat-ssh-server
    Hostname a2bg8me3awc9x8zb.onion
    ProxyCommand unixsocks --port 700 --socket-path /run/tor/behind-nat/users.sock --remote-host a2bg8me3awc9x8zb.onion
    IdentityFile ~/.ssh/behind-nat-ssh-server-backdoor
    User backdoor-user
```

## Building & Installing

There are four ways to obtain a binary:

1. You can build using cargo if you have a Rust toolchain installed by `cargo
   build --release` and just point your `ProxyCommand` to
   `unixsocks/target/bin/unixsocks`
   
1. To use an ephemeral environment with `unixsocks` available, you can run the
   `defaultApp` directly off of the flake with `nix run
   github:positron-solutions/unixsocks --command "unisocks" "arg" "arg" "arg"`
   
1. Also using nix flakes, you can run `nix build` and point `ProxyCommand` to
   `unixsocks/result-bin/bin/unixsocks`
   
1. On legacy nix, use plain `nix-build` on the above.
   
1. If you use home manager, you can include this repo in your inputs as either a
   flake input path or as a path to a locally checked out copy.
   
```nix home.nix

{ pkgs, ... }:
  let
    unixsocks = (import ./unixsocks/); # this is defaultPackage from the flake
  in {
    home.packages = [
      unixsocks
    ];
  } 
```

Build & activate this updated profile with `home-manager switch` and now
`unixsocks` will be available on your path.

## Development

This repository provides a shell that can be used with `nix develop` or by
`direnv activate`.  See [cargo2nix] for more information on debugging crate
builds.

[cargo2nix]: https://github.com/cargo2nix/cargo2nix

The environment includes all dependencies and state configuration to
successfully build this repository with just `cargo build`.  There are some
differences between the actual sanboxed build and the build in the development
shell, but they are minimized.
