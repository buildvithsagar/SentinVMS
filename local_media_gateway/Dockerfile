FROM dart:stable AS build
WORKDIR /src
COPY pubspec.yaml ./
RUN dart pub get
COPY . ./
RUN mkdir -p /out \
    && dart compile exe bin/server.dart -o /out/sentinvms-gateway

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        ffmpeg \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/sentinvms-gateway /app/sentinvms-gateway
EXPOSE 8090
ENTRYPOINT ["/app/sentinvms-gateway"]
