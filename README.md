# balena-firecracker

Append this build stage to your existing container image to automatically run as a microVM with Firecracker!

## What is Firecracker?

[Firecracker](https://firecracker-microvm.github.io/) is an open source virtualization technology that is purpose-built for creating and managing secure, multi-tenant container and function-based services that provide serverless operational models. Firecracker runs workloads in lightweight virtual machines, called microVMs, which combine the security and isolation properties provided by hardware virtualization technology with the speed and flexibility of containers.

## Requirements

Firecracker supports x86_64 and AARCH64 Linux, see [specific supported kernels](https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md).

Firecracker also requires [the KVM Linux kernel module](https://www.linux-kvm.org/).

The presence of the KVM module can be checked with:

```bash
lsmod | grep kvm
```

As such, the following device types have been tested:

- Generic x86_64 (GPT)
- Generic AARCH64

## Getting Started

Add the following lines to the end of your existing Dockerfile for publishing.

```Dockerfile
# The rest of your docker instructions up here...

# Create a tarball of your app's root file system
RUN tar cf /rootfs.tar /bin /etc /lib /root /sbin /usr

# Include firecracker wrapper and scripts
FROM ghcr.io/balena-io/fc-jailer AS runtime

# Copy the root file system tarball into the firecracker runtime image
COPY --from=rootfs /src/rootfs.tar ./
```

Then you can publish your container image as you normally would via container registries
or deploy it directly via Docker Compose.

```yml
version: "2"

services:
  my-app:
    build: .
    # Privileged is required to setup the rootfs and jailer
    # but permissions are dropped to a chroot in order to start your VM
    privileged: true
    network_mode: host
    # Optionally run the VM rootfs and kernel in-memory to save storage wear
    tmpfs:
      - /tmp
      - /run
      - /srv
    # Optionally mount a persistent data volume where a data drive will be created for the VM
    volumes:
      - persistent-data:/data

volumes:
  persistent-data: {}
```

That's it! The firecracker runtime image will execute your rootfs as a MicroVM.

Reference: <https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md>

## Usage

### Secrets

Since traditional container environment variables are not available in the VM, we've added
a step to inject them into the VM rootfs where they can be sourced or exported at runtime.

Provide environment variables or secrets with the `CTR_` prefix and they will be written to
`/var/secrets` at runtime.

If the values have spaces, or special characters, it is recommended to encode your secret values
with `base64` and have your init service decode them.

Your init service can optionally delete the secrets file after sourcing, leaving the VM in
a clean state with no secrets.

### Networking

A TAP/TUN device will be automatically created for the guest to have network access.

Reference: <https://github.com/firecracker-microvm/firecracker/blob/main/docs/network-setup.md>

### Resources

Resources like virtual CPUs and Memory can be overprovisioned and increased by mounting a custom
[VM config](https://github.com/firecracker-microvm/firecracker/blob/main/tests/framework/vm_config.json)
to `/usr/src/app/config.json` or via the env vars `VCPU_COUNT` and `MEM_SIZE_MIB`.

### Persistent Storage

The rootfs is recreated on every run, so anything written to the rootfs will not persist and
is considered ephemeral like container layers.

However an additional data filesystem will be created at `/data/datafs.ext4` for optional use,
and it can be made persistent by mounting a container volume to `/data`.

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.
