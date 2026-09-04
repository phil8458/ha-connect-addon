FROM ghcr.io/home-assistant/base:latest

ARG BUILD_ARCH=amd64
ARG FRP_VERSION=0.61.1

# Map HA arch names to frp release arch names
RUN set -eux; \
    case "${BUILD_ARCH}" in \
      amd64) FRP_ARCH=amd64 ;; \
      aarch64) FRP_ARCH=arm64 ;; \
      armv7) FRP_ARCH=arm ;; \
      armhf) FRP_ARCH=arm ;; \
      *) echo "Unsupported arch: ${BUILD_ARCH}" >&2; exit 1 ;; \
    esac; \
    apk add --no-cache curl jq bash; \
    curl -fsSL \
      "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz" \
      -o /tmp/frp.tar.gz; \
    tar -xzf /tmp/frp.tar.gz -C /tmp; \
    mv "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}/frpc" /usr/local/bin/frpc; \
    chmod +x /usr/local/bin/frpc; \
    rm -rf /tmp/frp*

COPY rootfs /
RUN chmod +x /usr/bin/ha-remote.sh

CMD ["/usr/bin/ha-remote.sh"]
