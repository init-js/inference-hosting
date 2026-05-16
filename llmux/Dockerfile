FROM rust:latest AS builder

WORKDIR /build
COPY . .
RUN mkdir -p /tmp/ && cd /tmp && \
    git clone https://github.com/doublewordai/llmux
RUN rustup target add x86_64-unknown-linux-musl && \
    apt-get update && apt-get install -y musl-tools build-essential pkg-config libssl-dev ca-certificates git && \
    command -v x86_64-linux-musl-gcc >/dev/null 2>&1 || ln -s /usr/bin/musl-gcc /usr/bin/x86_64-linux-musl-gcc
ENV CC_x86_64_unknown_linux_musl=x86_64-linux-musl-gcc
ENV CARGO_TARGET_X86_64_UNKNOWN_LINUX_MUSL_LINKER=x86_64-linux-musl-gcc
RUN mkdir -p /app && cd /tmp/llmux && \
    cargo install --path . --target x86_64-unknown-linux-musl && \
    mv /usr/local/cargo/bin/llmux /app/

# --- STAGE 2: Final Production Image ---
FROM alpine:latest
WORKDIR /app
# ONLY copy the final executable, discarding the heavy toolchain
COPY --from=builder /app/llmux . 
RUN ldd /app/llmux
ENTRYPOINT ["/app/llmux"]