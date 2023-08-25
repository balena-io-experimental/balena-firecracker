# balena-firecracker

Run Docker container images in Firecracker microVMs on balenaOS

## What is Firecracker?

[Firecracker](https://github.com/firecracker-microvm/firecracker) is an open source virtualization technology that is purpose-built for creating and managing secure, multi-tenant container and function-based services that provide serverless operational models. Firecracker runs workloads in lightweight virtual machines, called microVMs, which combine the security and isolation properties provided by hardware virtualization technology with the speed and flexibility of containers.

## What is firecracker-containerd?

[firecracker-containerd](https://github.com/firecracker-microvm/firecracker-containerd) enables the use of a container runtime, containerd, to manage Firecracker microVMs.

> Potential use cases of Firecracker-based containers include:
>
> Sandbox a partially or fully untrusted third party container in its own microVM. This would reduce the likelihood of leaking secrets via the third party container, for example.
> Bin-pack disparate container workloads on the same host, while maintaining a high level of isolation between containers. Because the overhead of Firecracker is low, the achievable container density per host should be comparable to running containers using kernel-based container runtimes, without the isolation compromise of such solutions. Multi-tenant hosts would particularly benefit from this use case.

## Supported Devices

Firecracker supports x86_64 and aarch64 Linux, see [specific supported kernels](https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md).

### KVM

Firecracker requires [the KVM Linux kernel module](https://www.linux-kvm.org/).

The presence of the KVM module can be checked with:

```bash
lsmod | grep kvm
```

## Usage

Set the env var `FICD_IMAGE_TAG` to the desired OCI-compliant container image and optionally provide a `FICD_CMD`.
Additional container runtime options can be provided via `FICD_EXTRA_OPTS`.
For a full list of options execute `firecracker-ctr run --help` in the service shell.

## Contributing

Please open an issue or submit a pull request with any features, fixes, or changes.

## Resources

- <https://actuated.dev/blog/kvm-in-github-actions>
- <https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md>
- <https://github.com/firecracker-microvm/firecracker/blob/main/docs/rootfs-and-kernel-setup.md>
- <https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md>
- <https://github.com/skatolo/nested-firecracker>
- <https://docs.docker.com/storage/storagedriver/device-mapper-driver/#manage-devicemapper>
- <https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/how-to-use-kata-containers-with-firecracker.md>
