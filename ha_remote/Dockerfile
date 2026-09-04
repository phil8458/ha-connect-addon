FROM alpine:3.21

# Set by BuildKit per platform (amd64 | arm64 | arm)
ARG TARGETARCH
ARG FRP_VERSION=0.61.1

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) FRP_ARCH=amd64 ;; \
      arm64) FRP_ARCH=arm64 ;; \
      arm) FRP_ARCH=arm ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    apk add --no-cache curl jq bash python3 ca-certificates tzdata; \
    curl -fsSL \
      "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz" \
      -o /tmp/frp.tar.gz; \
    tar -xzf /tmp/frp.tar.gz -C /tmp; \
    mv "/tmp/frp_${FRP_VERSION}_linux_${FRP_ARCH}/frpc" /usr/local/bin/frpc; \
    chmod +x /usr/local/bin/frpc; \
    rm -rf /tmp/frp*

COPY rootfs /
RUN chmod +x /usr/bin/ha-remote.sh /usr/bin/set-external-url.py

CMD ["/usr/bin/ha-remote.sh"]
