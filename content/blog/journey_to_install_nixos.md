+++
title = "A journey to install NixOS"
author = ["Bastien Riviere"]
date = 2021-06-28
tags = ["nix", "nixos", "darwin"]
draft = true
+++

## A journey to install NixOS {#a-journey-to-install-nixos}

Today, I want to install NixOS on my old laptop. His goal is to be a multi-arch builder. That means it will support these architectures:

- x86_64-linux (native)
- x86_64-darwin (qemu)
- and more arch via cross-compilation (if possible)

Why I am doing this? Currently, I have a macbook pro from my current job. To be honest, it doesn't have great performance.
Docker on Mac is, to be honest, a nightmare in term of performance, and since we are developping a big application (in Elixir),
it requires a beefy machine.

### Plan {#plan}

First, we will setup NixOS as we always do:

- download NixOS iso
- flash it on an USB device
- boot it on your machine
- partition disk
- generate NixOS config
- setup wifi (my laptop doesn't have an ethernet port)

Then, we will write a small configuration setup on my working machine. Since I am using Nix flake, the configuration will be available
in my github repository.

We want these services to be enabled:

- docker (I don't want to run it on my mac anymore)
- prometheus and grafana (for those nice graphs)
- nix-serve (to serve binary cache)
- and maybe more...

And for the final step, and the most painful one, find a way to:

- create a OSX instance via qemu
- find a way to make it replicable with NixOS/NixOps

### Setting up NixOS {#setting-up-nixos}

Let's start by downloading the iso from [NixOS Download Page](https://nixos.org/download.html). Personnaly, I always take the minimal iso image since I don't need graphical
interface (and there is no graphical installer, so I guess it's only for testing purpose?).

Now, we can flash that iso into a USB drive. It's easy as that:

```shell
dd if=~/Downloads/nixos-minimal-...-x86_64-linux.iso of=/dev/sdx
```

Replace `/dev/sdx` with the correct device on your system. If you don't know how to find it, you can run:

```shell
# On Linux
lsblk -b
# On MacOS
diskutil list
```