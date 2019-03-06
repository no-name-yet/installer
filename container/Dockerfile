FROM quay.io/pod_utils/systemd-libvirt:1.0.3

RUN yum -y --setopt=skip_missing_names_on_install=True \ 
        install \
        NetworkManager \
        dnsmasq \
        augeas; \
        yum clean all; \
        systemctl enable NetworkManager

# Misc configurations
COPY augconf /augconf
RUN augtool -f /augconf
