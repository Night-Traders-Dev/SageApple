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
> `6.6.63-ky` kernel ships without it, but it can be built and installed from
> the vendor headers -- see
> [Enabling `cdc_acm`](#enabling-cdc_acm). `con 2` is therefore usable on this
> kernel now, as long as the module is loaded.

### Enabling `cdc_acm`

The chip enumerates as class 2 / subclass 2 / protocol 1 plus a CDC data
interface, so nothing but `cdc_acm` will claim it, and `usbserial` will not. The
kernel config has `CONFIG_USB_SERIAL` with CH341/CP210x and no CDC ACM at all,
so the driver has to come from a module.

The vendor ships the matching headers as a `.deb` that is **not installed by
default** -- it is staged in `/opt`:

```console
# ls -la /opt/linux-headers-current-ky_1.0.0_riscv64.deb
dpkg -i /opt/linux-headers-current-ky_1.0.0_riscv64.deb
```

That package supplies `/lib/modules/6.6.63-ky/build` with `Module.symvers` and
prebuilt `scripts/`, and its `include/config/kernel.release` is `6.6.63-ky`, so
a module built against it gets the running kernel's vermagic to the letter:

```
vermagic: 6.6.63-ky SMP preempt mod_unload riscv
```

A headers package has no driver source, so take `cdc-acm.c` from the exact
upstream tag and build it as a single-file out-of-tree module:

```console
curl -O https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.63.tar.xz
tar -xJf linux-6.6.63.tar.xz --wildcards 'linux-6.6.63/drivers/usb/class/cdc-acm*'
mkdir -p /tmp/cdcacm-build && cd /tmp/cdcacm-build
cp /tmp/linux-6.6.63/drivers/usb/class/cdc-acm.{c,h} .
printf 'obj-m += cdc-acm.o\n' > Makefile
make -C /lib/modules/6.6.63-ky/build M=/tmp/cdcacm-build modules
```

To make it survive a reboot, install it where `depmod` can find it and ask for
it at boot:

```console
install -m 0644 /tmp/cdcacm-build/cdc-acm.ko /lib/modules/$(uname -r)/extra/
depmod -a $(uname -r)
printf 'cdc_acm\n' > /etc/modules-load.d/cdc-acm.conf
modprobe cdc_acm
```

`/dev/ttyACM0` then appears, and the board talks to avrdude at 115200 like any
other Uno, reporting signature `0x1e950f`.

Two things this avoids, worth recording because they are the obvious next
attempt and both fail:

- **A module from another kernel.** `cdc-acm.ko` out of Ubuntu
  `linux-modules-6.8.0-31-generic` returns `Invalid module format` -- its
  vermagic is `6.8.0-31-generic ...`. `CONFIG_MODULE_FORCE_LOAD` is not set, so
  the string cannot be bypassed, and booting a generic Ubuntu RISC-V kernel
  would take the board down on the vendor DTB and `boot.scr` chain.
- **USB/IP to another host.** There is no `usbip` package in any configured
  repository, and the local side would need `vhci-hcd` and root anyway.

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
