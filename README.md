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

Firecracker also requires [the KVM Linux kernel module](https://www.linux-kvm.org/).

The presence of the KVM module can be checked with:

```bash
lsmod | grep kvm
```

As such, the following device types have been tested:

- Generic x86_64 (GPT)
- Generic AARCH64

## Getting Started

You can one-click-deploy this project to balena using the button below:

[![deploy button](https://balena.io/deploy.svg)](https://dashboard.balena-cloud.com/deploy?repoUrl=https://github.com/balena-io-experimental/balena-firecracker&defaultDeviceType=generic-amd64)

## Manual Deployment

Alternatively, deployment can be carried out by manually creating a [balenaCloud account](https://dashboard.balena-cloud.com) and application, flashing a device, downloading the project and pushing it via the [balena CLI](https://github.com/balena-io/balena-cli).

## Usage

### Guest Image

Set the env var `FICD_IMAGE_TAG` to the desired OCI-compliant container image tag and it will be pulled and executed as the guest container.

If the image registry needs credentials or similar, custom pull options can be provided with `FICD_IMAGE_PULL_OPTIONS` such as `--user user:pass`

See below for a full list of options or execute `firecracker-ctr images pull --help` in the service shell.

```
NAME:
   firecracker-ctr images pull - pull an image from a remote

USAGE:
   firecracker-ctr images pull [command options] [flags] <ref>

DESCRIPTION:
   Fetch and prepare an image for use in containerd.

After pulling an image, it should be ready to use the same reference in a run
command. As part of this process, we do the following:

1. Fetch all resources into containerd.
2. Prepare the snapshot filesystem with the pulled resources.
3. Register metadata for the image.


OPTIONS:
   --skip-verify, -k                 skip SSL certificate validation
   --plain-http                      allow connections using plain HTTP
   --user value, -u value            user[:password] Registry user and password
   --refresh value                   refresh token for authorization server
   --hosts-dir value                 Custom hosts configuration directory
   --tlscacert value                 path to TLS root CA
   --tlscert value                   path to TLS client certificate
   --tlskey value                    path to TLS client key
   --http-dump                       dump all HTTP request/responses when interacting with container registry
   --http-trace                      enable HTTP tracing for registry interactions
   --snapshotter value               snapshotter name. Empty value stands for the default value. [$CONTAINERD_SNAPSHOTTER]
   --label value                     labels to attach to the image
   --platform value                  Pull content from a specific platform
   --all-platforms                   pull content and metadata from all platforms
   --all-metadata                    Pull metadata for all platforms
   --print-chainid                   Print the resulting image's chain ID
   --max-concurrent-downloads value  Set the max concurrent downloads for each pull (default: 0)
```

### Guest Container

A custom run COMMAND can be provided via `FICD_RUN_COMMAND` followed by one or more ARGS via `FICD_RUN_ARG_[*]` environment variables.

Extra run options can be provided via `FICD_RUN_OPTIONS`.

See below for a full list of options or execute `firecracker-ctr run --help` in the service shell.

```text
NAME:
   firecracker-ctr run - run a container

USAGE:
    firecracker-ctr run [command options] [flags] Image|RootFS ID [COMMAND] [ARG...]

OPTIONS:
   --rm                                    remove the container after running, cannot be used with --detach
   --null-io                               send all IO to /dev/null
   --log-uri value                         log uri
   --detach, -d                            detach from the task after it has started execution, cannot be used with --rm
   --fifo-dir value                        directory used for storing IO FIFOs
   --cgroup value                          cgroup path (To disable use of cgroup, set to "" explicitly)
   --platform value                        run image for specific platform
   --cni                                   enable cni networking for the container
   --runc-binary value                     specify runc-compatible binary
   --runc-root value                       specify runc-compatible root
   --runc-systemd-cgroup                   start runc with systemd cgroup manager
   --uidmap container-uid:host-uid:length  run inside a user namespace with the specified UID mapping range; specified with the format container-uid:host-uid:length
   --gidmap container-gid:host-gid:length  run inside a user namespace with the specified GID mapping range; specified with the format container-gid:host-gid:length
   --remap-labels                          provide the user namespace ID remapping to the snapshotter via label options; requires snapshotter support
   --cpus value                            set the CFS cpu quota (default: 0)
   --cpu-shares value                      set the cpu shares (default: 1024)
   --snapshotter value                     snapshotter name. Empty value stands for the default value. [$CONTAINERD_SNAPSHOTTER]
   --snapshotter-label value               labels added to the new snapshot for this container.
   --config value, -c value                path to the runtime-specific spec config file
   --cwd value                             specify the working directory of the process
   --env value                             specify additional container environment variables (e.g. FOO=bar)
   --env-file value                        specify additional container environment variables in a file(e.g. FOO=bar, one per line)
   --label value                           specify additional labels (e.g. foo=bar)
   --annotation value                      specify additional OCI annotations (e.g. foo=bar)
   --mount value                           specify additional container mount (e.g. type=bind,src=/tmp,dst=/host,options=rbind:ro)
   --net-host                              enable host networking for the container
   --privileged                            run privileged container
   --read-only                             set the containers filesystem as readonly
   --runtime value                         runtime name (default: "io.containerd.runc.v2")
   --runtime-config-path value             optional runtime config path
   --tty, -t                               allocate a TTY for the container
   --with-ns value                         specify existing Linux namespaces to join at container runtime (format '<nstype>:<path>')
   --pid-file value                        file path to write the task's pid
   --gpus value                            add gpus to the container
   --allow-new-privs                       turn off OCI spec's NoNewPrivileges feature flag
   --memory-limit value                    memory limit (in bytes) for the container (default: 0)
   --device value                          file path to a device to add to the container; or a path to a directory tree of devices to add to the container
   --cap-add value                         add Linux capabilities (Set capabilities with 'CAP_' prefix)
   --cap-drop value                        drop Linux capabilities (Set capabilities with 'CAP_' prefix)
   --seccomp                               enable the default seccomp profile
   --seccomp-profile value                 file path to custom seccomp profile. seccomp must be set to true, before using seccomp-profile
   --apparmor-default-profile value        enable AppArmor with the default profile with the specified name, e.g. "cri-containerd.apparmor.d"
   --apparmor-profile value                enable AppArmor with an existing custom profile
   --rdt-class value                       name of the RDT class to associate the container with. Specifies a Class of Service (CLOS) for cache and memory bandwidth management.
   --rootfs                                use custom rootfs that is not managed by containerd snapshotter
   --no-pivot                              disable use of pivot-root (linux only)
   --cpu-quota value                       Limit CPU CFS quota (default: -1)
   --cpu-period value                      Limit CPU CFS period (default: 0)
   --rootfs-propagation value              set the propagation of the container rootfs
```

### Guest Secrets

Ephemeral secrets can be provided to the container runtime via `FICD_SECRET_[*]` environment variables.

Each secret will be written to `/run/secrets/{secret_key}` in the VM and `/run/secrets` is mounted into the container.

The container can use these secrets as needed, and should delete `/run/secrets/*` during init to avoid leaking.

On next firecracker service container start, the secrets will be repopulated.

### Guest Restart

If the guest container exits with code 0, it will be restarted without killing the firecracker service container.

This behaviour can be turned off by setting `FICD_KEEP_ALIVE=false` which will result in the firecracker service restarting if the guest container exits.

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
