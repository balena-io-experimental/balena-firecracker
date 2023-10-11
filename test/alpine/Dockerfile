FROM alpine:3.18 AS alpine-rootfs

# WORKDIR /src

# # hadolint ignore=DL3018
# RUN apk add --no-cache openrc util-linux

# # Set up a login terminal on the serial console (ttyS0)
# RUN ln -s agetty /etc/init.d/agetty.ttyS0 \
#     && echo ttyS0 > /etc/securetty \
#     && rc-update add agetty.ttyS0 default

# # Make sure special file systems are mounted on boot
# RUN rc-update add devfs boot \
#     && rc-update add procfs boot \
#     && rc-update add sysfs boot

# # Create a tarball of the root file system
# RUN tar cf /rootfs.tar /bin /etc /lib /root /sbin /usr

# hadolint ignore=DL3018
RUN apk add --no-cache curl iproute2

###############################################

# Include firecracker wrapper and scripts
FROM localhost:5000/sut AS runtime

# Copy the root file system from your container final stage
COPY --from=alpine-rootfs / /usr/src/app/rootfs/
