#!/usr/bin/env sh

# https://github.com/firecracker-microvm/firecracker-containerd/blob/main/docs/getting-started.md

set -eu

trap '/app/devmapper/cleanup.sh' EXIT

/app/devmapper/cleanup.sh
/app/devmapper/create.sh

mkdir -p /var/lib/firecracker-containerd

# start containerd
firecracker-containerd --config /etc/firecracker-containerd/config.toml &

# pull an image
firecracker-ctr --address /run/firecracker-containerd/containerd.sock images pull \
    --snapshotter devmapper \
    docker.io/library/busybox:latest

# start a container
firecracker-ctr --address /run/firecracker-containerd/containerd.sock run \
    --snapshotter devmapper \
    --runtime aws.firecracker \
    --rm --net-host \
    docker.io/library/busybox:latest busybox-test

# NAME:
#    firecracker-ctr run - run a container

# USAGE:
#    firecracker-ctr run [command options] [flags] Image|RootFS ID [COMMAND] [ARG...]

# OPTIONS:
#    --rm                                    remove the container after running, cannot be used with --detach
#    --null-io                               send all IO to /dev/null
#    --log-uri value                         log uri
#    --detach, -d                            detach from the task after it has started execution, cannot be used with --rm
#    --fifo-dir value                        directory used for storing IO FIFOs
#    --cgroup value                          cgroup path (To disable use of cgroup, set to "" explicitly)
#    --platform value                        run image for specific platform
#    --cni                                   enable cni networking for the container
#    --runc-binary value                     specify runc-compatible binary
#    --runc-root value                       specify runc-compatible root
#    --runc-systemd-cgroup                   start runc with systemd cgroup manager
#    --uidmap container-uid:host-uid:length  run inside a user namespace with the specified UID mapping range; specified with the format container-uid:host-uid:length
#    --gidmap container-gid:host-gid:length  run inside a user namespace with the specified GID mapping range; specified with the format container-gid:host-gid:length
#    --remap-labels                          provide the user namespace ID remapping to the snapshotter via label options; requires snapshotter support
#    --cpus value                            set the CFS cpu quota (default: 0)
#    --cpu-shares value                      set the cpu shares (default: 1024)
#    --snapshotter value                     snapshotter name. Empty value stands for the default value. [$CONTAINERD_SNAPSHOTTER]
#    --snapshotter-label value               labels added to the new snapshot for this container.
#    --config value, -c value                path to the runtime-specific spec config file
#    --cwd value                             specify the working directory of the process
#    --env value                             specify additional container environment variables (e.g. FOO=bar)
#    --env-file value                        specify additional container environment variables in a file(e.g. FOO=bar, one per line)
#    --label value                           specify additional labels (e.g. foo=bar)
#    --annotation value                      specify additional OCI annotations (e.g. foo=bar)
#    --mount value                           specify additional container mount (e.g. type=bind,src=/tmp,dst=/host,options=rbind:ro)
#    --net-host                              enable host networking for the container
#    --privileged                            run privileged container
#    --read-only                             set the containers filesystem as readonly
#    --runtime value                         runtime name (default: "io.containerd.runc.v2")
#    --runtime-config-path value             optional runtime config path
#    --tty, -t                               allocate a TTY for the container
#    --with-ns value                         specify existing Linux namespaces to join at container runtime (format '<nstype>:<path>')
#    --pid-file value                        file path to write the task's pid
#    --gpus value                            add gpus to the container
#    --allow-new-privs                       turn off OCI spec's NoNewPrivileges feature flag
#    --memory-limit value                    memory limit (in bytes) for the container (default: 0)
#    --device value                          file path to a device to add to the container; or a path to a directory tree of devices to add to the container
#    --cap-add value                         add Linux capabilities (Set capabilities with 'CAP_' prefix)
#    --cap-drop value                        drop Linux capabilities (Set capabilities with 'CAP_' prefix)
#    --seccomp                               enable the default seccomp profile
#    --seccomp-profile value                 file path to custom seccomp profile. seccomp must be set to true, before using seccomp-profile
#    --apparmor-default-profile value        enable AppArmor with the default profile with the specified name, e.g. "cri-containerd.apparmor.d"
#    --apparmor-profile value                enable AppArmor with an existing custom profile
#    --rdt-class value                       name of the RDT class to associate the container with. Specifies a Class of Service (CLOS) for cache and memory bandwidth management.
#    --rootfs                                use custom rootfs that is not managed by containerd snapshotter
#    --no-pivot                              disable use of pivot-root (linux only)
#    --cpu-quota value                       Limit CPU CFS quota (default: -1)
#    --cpu-period value                      Limit CPU CFS period (default: 0)
#    --rootfs-propagation value              set the propagation of the container rootfs
