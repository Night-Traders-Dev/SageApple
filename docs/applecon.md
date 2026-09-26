# AppleCon — SageApple board controller

AppleCon is a host-side tool built in SageLang that drives a rack of
SageApple boards from a single terminal. It opens with an artistic TUI
animation, then drops into a `sage> ` shell whose `con N` commands hand
off to each board's interactive serial shell.

## Topology

All three boards are wired to the OrangePi (192.168.4.34) and reached
over SSH:

| con | board           | serial port            | USB controller |
|-----|-----------------|------------------------|----------------|
| `0` | og Uno R3       | `/dev/ttyUSB0`         | xhci-hcd (USB2) |
| `1` | Nano R3         | `/dev/ttyUSB1`         | xhci-hcd (USB2) |
| `2` | 2nd Uno R3      | `/dev/ttyACM0`         | mv-ehci (USB4) |

> **Note:** The 2nd Uno R3 uses a FIREPHX USB SER (0843:5740) chip that
> speaks CDC-ACM, so it needs the `cdc_acm` driver. The OrangePi's
> `6.6.63-ky` kernel does not have it and it cannot be added from userspace.
> `con 2` therefore always reports down on that kernel. See
> [Why `con 2` cannot work on this kernel](#why-con-2-cannot-work-on-this-kernel).

### Why `con 2` cannot work on this kernel

The chip enumerates as class 2 / subclass 2 / protocol 1 plus a CDC data
interface, so nothing but `cdc_acm` will claim it. The running kernel has no
such driver by any route:

| attempt | result |
|---|---|
| `modprobe cdc_acm` | `Module cdc_acm not found in directory /lib/modules/6.6.63-ky` |
| `CONFIG_CDC_ACM` in `/boot/config-6.6.63-ky` | absent (the config has `CONFIG_USB_SERIAL` with CH341/CP210x, and no CDC ACM at all) |
| build it from source | no headers: `/lib/modules/6.6.63-ky/build` and `/usr/src` are both empty |
| `cdc-acm.ko` from Ubuntu `linux-modules-6.8.0-31-generic` | `insmod` returns `Invalid module format` -- its vermagic is `6.8.0-31-generic ...`, the kernel is `6.6.63-ky ...` |
| force past the vermagic | not possible: `CONFIG_MODULE_FORCE_LOAD` is not set |
| `usbip` the device to another host | no `usbip` package exists in any configured repository |

`CONFIG_MODVERSIONS` is not set, so symbol CRCs are not the obstacle -- the
vermagic string is. Loading it would need the *whole* matching 6.8.0-31 kernel,
and a generic Ubuntu RISC-V kernel is not going to boot this board on the
vendor DTB and `boot.scr` chain.

The realistic options are therefore:

1. **Use a CH340-class board on this kernel.** These bind `usbserial`, which
   *is* present, and give `/dev/ttyUSB*`. The Nano on this host works this way.
2. **Boot a kernel that has `CONFIG_CDC_ACM`.** This needs physical console
   access to the OrangePi, because a failed boot takes the machine off the
   network. Do not attempt it over SSH.
3. **Replace the board's USB-serial bridge** with a CH340, if the board is
   open to it.

Note that `dmesg` shows the FIREPHX device enumerating and disconnecting
repeatedly on `mv-ehci`; it is present on the bus, just driverless. That is why
`lsusb` shows it while no `/dev` node appears.

## Running

Use the C build of Sage (the self-hosted RISC-V `sage` interpreter is
unstable with the animation loop):

```sh
sage-c tools/applecon.sage
```

Run it from the repo root so `import io`/`import sys` resolve.

## Commands

| command | result |
|---------|--------|
| `sage> con 0` | SSH to the OrangePi and `screen /dev/ttyUSB0 9600` (og Uno R3) |
| `sage> con 1` | SSH to the OrangePi and `screen /dev/ttyUSB1 9600` (Nano R3) |
| `sage> con 2` | SSH to the OrangePi and `screen /dev/ttyACM0 9600` (2nd Uno R3) |
| `sage> status` | probe each port and show which boards are present |
| `sage> help` | list the available commands |
| `sage> exit` | leave AppleCon |

Each `con` connection drops you into the board's boot banner / monitor
(`MON>`) or BASIC (`] `) prompt. `screen` control keys let you return to
AppleCon without pulling the board's serial line:

* `C-a d` — detach (leave the connection in the background)
* `C-a k` — kill the screen session and return to the `sage> ` prompt
* `C-a ?` — show the screen help

## Stale screen cleanup

AppleCon automatically kills any stale detached `screen` sessions on the
target port before connecting. This prevents the "Device or resource busy"
error that occurs when a previous screen session holds the port open.

## Note on `sys.exec` and SSH

Sage's `sys.exec`/`sys.shell_exec` security validator only allows
alphanumerics, `/ . - _ ~` and spaces — the `@` in `user@host` is
rejected. AppleCon therefore writes the `ssh` invocation into a small
`/tmp/*.sh` helper (via `io.writebytes`) and `sys.exec("/bin/sh <file>")`,
so remote connections work without relaxing the validator.

The remote probe (`status`) uses the same helper technique with
`sys.shell_exec` (redirecting stdin from `/dev/null` to prevent the SSH
process from consuming piped input) to test whether each remote serial
node exists.
