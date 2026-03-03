FROM alpine:latest AS alpine-builder

# ── shared stage: pre-built tshark from Alpine ────────────────────────────────
FROM alpine-builder AS alpine-tshark
RUN apk add --no-cache tshark

# ── arm/v6: build tshark from source (no pre-built Alpine package) ────────────
FROM alpine-builder AS builder-linux-arm-v6
RUN apk add --no-cache \
        build-base cmake ninja git perl python3 \
        flex glib-dev libpcap-dev libgcrypt-dev \
        c-ares-dev pcre2-dev speexdsp-dev libxml2-dev && \
    git clone --depth 1 https://gitlab.com/wireshark/wireshark.git /tmp/wireshark && \
    cmake -G Ninja \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DENABLE_WERROR=OFF \
        -DBUILD_wireshark=OFF \
        -DBUILD_stratoshark=OFF \
        -DBUILD_tshark=ON \
        -DBUILD_dumpcap=ON \
        -DBUILD_editcap=OFF \
        -DBUILD_capinfos=OFF \
        -DBUILD_captype=OFF \
        -DBUILD_mergecap=OFF \
        -DBUILD_reordercap=OFF \
        -DBUILD_text2pcap=OFF \
        -DBUILD_randpkt=OFF \
        -DBUILD_rawshark=OFF \
        -DBUILD_dftest=OFF \
        -S /tmp/wireshark \
        -B /tmp/wireshark-build && \
    cmake --build /tmp/wireshark-build && \
    cmake --install /tmp/wireshark-build && \
    rm -rf /tmp/wireshark /tmp/wireshark-build

# ── all other platforms: use pre-built Alpine package ─────────────────────────
FROM alpine-tshark AS builder-linux-amd64-none
FROM alpine-tshark AS builder-linux-arm-v7
FROM alpine-tshark AS builder-linux-arm64-none
FROM alpine-tshark AS builder-linux-386-none
FROM alpine-tshark AS builder-linux-ppc64le-none
FROM alpine-tshark AS builder-linux-riscv64-none
FROM alpine-tshark AS builder-linux-s390x-none

# ── select the stage that matches the current platform ────────────────────────
# BuildKit only evaluates the referenced stage; all others are skipped,
# so each platform's RUN layer is cached independently.
# TARGETVARIANT is empty for platforms without a variant (amd64, 386, etc.),
# hence the trailing dash in those stage names above.
ARG TARGETARCH
ARG TARGETVARIANT
# ${TARGETVARIANT:-none}: Docker treats empty string as unset with :-,
# so platforms without a variant (amd64, 386, …) resolve to e.g. builder-linux-amd64-none.
FROM builder-linux-${TARGETARCH}-${TARGETVARIANT:-none} AS builder

FROM scratch AS production

# Entire library directories
COPY --from=builder /lib     /lib
COPY --from=builder /usr/lib /usr/lib

# Binaries
COPY --from=builder /usr/bin/tshark   /usr/bin/tshark
COPY --from=builder /usr/bin/dumpcap  /usr/bin/dumpcap

# Wireshark protocol dissectors
COPY --from=builder /usr/share/wireshark /usr/share/wireshark

# Minimal user/group info
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group  /etc/group

VOLUME ["/capture"]

ENTRYPOINT ["/usr/bin/tshark", "-i", "any", "-p" "-w", "/capture/capture.pcap"]
