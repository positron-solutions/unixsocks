# Unixsocks

Want to ssh over a tor service but `socat` doesn't accept unix addresses and you've configured your tor client to serve local clients over a unix socket?  This is your tool!

## Usage

If your tor service is exposing a unix socket to your user at `/run/tor/behind-nat/users.sock` and has the tor address `a2bg8me3awc9x8zb.onion` which accpets connections on `700` and forwards those to a remote ssh server started on demand, your ssh config in `~/.ssh/config` will contain entries like this:

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

There are three ways to obtain a binary:

1. You can build using cargo if you have a Rust toolchain installed by `cargo build --release` and just point your `ProxyCommand` to `my/checked/out/unixsocks/target/bin/unixsocks`
1. If your Rust toolchain has issues or you use nix already, try using the nix pinned dependencies by `nix build -A unixsocks` and point `ProxyCommand` to `/my/checked/out/unixsocks/result/bin/unixsocks`
1. If you use home manager, you can include this repo as a source via local `niv` pin or just direct path import
```nix home.nix

{ pkgs, ... }:
  let
    unixsocks = import ./unixsocks/;
  in {
    home.packages = [
      unixsocks
    ];
  } 
```
Build & activate this updated profile with `home-manager switch` and now `unixsocks` will be available on your path.
