# Use the official Ubuntu image as a base
FROM ubuntu:jammy AS ubuntu-rootfs

# # Set environment variables to avoid prompts
# ENV DEBIAN_FRONTEND=noninteractive

# # Install the necessary packages
# # hadolint ignore=DL3008
# RUN apt-get update \
#     && apt-get install -y --no-install-recommends curl systemd systemd-sysv \
#     && rm -rf /var/lib/apt/lists/*

# # Remove unnecessary services
# RUN find /etc/systemd/system \
#         /lib/systemd/system \
#         \( \
#         -name "*udev*" \
#         -o -name "*resolved*" \
#         -o -name "*logind*" \
#         -o -name "*getty*" \
#         -o -name "*networkd*" \
#         \) \
#         -exec rm -f {} \;

# # Set systemd as the entrypoint
# STOPSIGNAL SIGRTMIN+3
# CMD [ "/sbin/init" ]

# # Set up necessary mount points
# VOLUME [ "/sys/fs/cgroup" ]

# # Copy the updated systemd service file
# COPY entrypoint.service /etc/systemd/system/entrypoint.service
# RUN systemctl enable entrypoint.service

# COPY init /init
# RUN chmod +x /init

# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl iproute2 \
    && rm -rf /var/lib/apt/lists/*

###############################################

# Include firecracker wrapper and scripts
FROM localhost:5000/sut AS runtime

# Copy the root file system from your container final stage
COPY --from=ubuntu-rootfs / /usr/src/app/rootfs/
