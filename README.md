# balena-firecracker

Run Docker container images as Firecracker virtual machines on balenaOS

## What is Firecracker?

[Firecracker](https://github.com/firecracker-microvm/firecracker) is an open source virtualization technology that is purpose-built for creating and managing secure, multi-tenant container and function-based services that provide serverless operational models. Firecracker runs workloads in lightweight virtual machines, called microVMs, which combine the security and isolation properties provided by hardware virtualization technology with the speed and flexibility of containers.

## Goals

The main goal of this project is to create Firecracker virtual machines on a balenaOS host
from inside a privileged service container.

Additionally, the rootfs for the VM should be created from an existing Docker container image,
downloaded and converted to raw format.

## Architecture & OS

Firecracker supports x86_64 and aarch64 Linux, see [specific supported kernels](https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md).

### KVM

Firecracker requires [the KVM Linux kernel module](https://www.linux-kvm.org/).

The presence of the KVM module can be checked with:

```bash
lsmod | grep kvm
```

An example output where it is enabled:

```bash
kvm_intel             348160  0
kvm                   970752  1 kvm_intel
irqbypass              16384  1 kvm
```

## Resources

- <https://actuated.dev/blog/kvm-in-github-actions>
- <https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md>
- <https://github.com/skatolo/nested-firecracker>
