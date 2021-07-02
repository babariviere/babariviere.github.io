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

### Installing NixOS {#installing-nixos}

Let's start by downloading the iso from [NixOS Download Page](https://nixos.org/download.html). Personally, I always take the minimal ISO image since I don't need graphical
interface (and there is no graphical installer, so I guess it's only for testing purpose?).

Now, we can flash that iso into a USB drive. It's easy as that:

```shell
sudo dd if=~/Downloads/nixos-minimal-...-x86_64-linux.iso of=/dev/sdx
sync # ensure that everything is written on the disk
```

Replace `/dev/sdx` with the correct device on your system. If you don't know how to find it, you can run:

```shell
# On Linux
lsblk -b
# On MacOS
diskutil list
```

Everything is explained here from the official documentation: <https://nixos.org/manual/nixos/stable/index.html#sec-booting-from-usb>

Now that our USB device is ready, let's boot it!

First thing: we need to setup the network. If you have an ethernet cable, you will probably have an internet connection, otherwise, setup internet via \`wpa_supplicant\` (you should look [here](https://nixos.org/manual/nixos/stable/index.html#sec-installation-booting-networking)).

After that, we are setting up our partitions.
I usually do this partitioning:

| partition | size           | fs type |
| --------- | -------------- | ------- |
| /boot     | 1GB            | fat32   |
| <swap>    | <ram size / 2> | swap    |

Since I am using ZFS, I use this documentation as an helper: <https://nixos.wiki/wiki/NixOS%5Fon%5FZFS>

For my ZFS pool setup, I have this:

```shell
$ zpool create -O mountpoint=none -f tank /dev/nvme1n1p3 /dev/nvme0n1p1
$ zfs create -o mountpoint=legacy tank/system
$ zfs create -o mountpoint=legacy tank/system/var
$ zfs create -o mountpoint=legacy tank/local
$ zfs create -o mountpoint=legacy -o compression=on -o atime=off tank/local/nix
$ zfs create -o mountpoint=legacy tank/user
$ zfs create -o mountpoint=legacy tank/user/home
$ zfs set xattr=sa acltype=posixacl tank/system/var

$ zfs list
NAME              USED  AVAIL     REFER  MOUNTPOINT
tank              438K   651G       24K  none
tank/local         48K   651G       24K  legacy
tank/local/nix     24K   651G       24K  legacy
tank/system        48K   651G       24K  legacy
tank/system/var    24K   651G       24K  legacy
tank/user          48K   651G       24K  legacy
tank/user/home     24K   651G       24K  legacy
```

You probably want to read this for best partitions: <https://grahamc.com/blog/nixos-on-zfs>

So, my partition is correctly setup, I can now mount everything and generate my config:

```shell
$ mount -t zfs tank/system /mnt
$ mkdir -p /mnt/{home,var,nix}
$ mount -t zfs tank/local/nix /mnt/nix
$ mount -t zfs tank/system/var /mnt/var
$ mount -t zfs tank/user/home /mnt/home
$ nixos-generate-config --root /mnt
```

After modifying the configuration, and ensuring that the configuration file contains:

```nix
  boot.initrd.supportedFilesystems = [ "zfs" ];
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostId = "<head -c 8 /etc/machine-id>";
  networking.wireless.enable = true; # if you don't have ethernet
  networking.wireless.interfaces = ["<interface>"];
```

If you are on laptop, add this to your configuration:

```nix
services.logind.lidSwitch = "ignore";
```

It will disable the "sleep on lid close".

And finally:

```shell
$ nixos-install
```

Yeah! NixOS is now installed!

It's not time for reboot.

### Configuring our machine {#configuring-our-machine}

#### Setup Tailscale and SSH {#setup-tailscale-and-ssh}

Let's by enabling OpenSSH so we can access remotely our machine.

To do this, start by adding this in your configuration:

```nix
services.openssh.enable = true;
```

Now, connect to your machine and copy your public ssh key so you don't have to enter the password again.

Next, we can setup tailscale. It is as simple as this:

```nix
services.tailscale.enable = true;
networking.firewall = {
  allowedUDPPorts = [ config.services.tailscale.port ];
  # required if you want to SSH to the machine, for example
  trustedInterfaces = [ config.services.tailscale.interfaceName ];
};
```

Activate both services with:

```shell
nixos-rebuild switch
```

Go to tailscale admin console, and generate a temporary key (one-time usage).
It will be used to connect to tailscale without the user interface.

Once you have your key, run this command:

```shell
tailscale up --authkey tskey-...
```

And now your machine is connected to the private network!

Since you can access it from tailscale, let's make the SSH port private (by excluding it from the firewall).

```nix
services.openssh.openFirewall = false;
```

Don't forget to `nixos-rebuild switch`!

You can check that it's now inaccessible by running your usual ssh command. It should get stuck and you will have a timeout.
To access it, you have to use the private IP from tailscale.

#### Enable nix-serve {#enable-nix-serve}
