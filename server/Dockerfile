# Dockerfile para o servidor dedicado de Charge Arena (Godot 4.7 Headless)
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION=4.7.1
ENV PORT=27941

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Baixar e instalar binário do Godot Linux Headless
RUN ARCH="$(uname -m)" && \
    if [ "$ARCH" = "x86_64" ]; then GODOT_ARCH="x86_64"; \
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then GODOT_ARCH="arm64"; \
    else echo "Arquitetura nao suportada: $ARCH" && exit 1; fi && \
    curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH}.zip" && \
    unzip -q /tmp/godot.zip -d /usr/local/bin && \
    mv /usr/local/bin/Godot_v${GODOT_VERSION}-stable_linux.${GODOT_ARCH} /usr/local/bin/godot && \
    chmod +x /usr/local/bin/godot && \
    rm -rf /tmp/godot.zip

# Criar usuario sem privilegios
RUN useradd -m -s /bin/bash charge
WORKDIR /app

# Copiar arquivos do jogo necessarios para o servidor
COPY project.godot /app/
COPY scripts/ /app/scripts/
COPY scenes/ /app/scenes/
COPY systems/ /app/systems/

RUN chown -R charge:charge /app
USER charge

EXPOSE 27941/udp

ENTRYPOINT ["sh", "-c", "godot --headless --path /app --script res://scripts/network/server_main.gd -- --port=${PORT}"]

