FROM debian:bookworm-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates clang curl python3 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY scripts/install-bend.sh scripts/install-bend.sh
RUN scripts/install-bend.sh /opt/bend
ENV PATH="/opt/bend/bin:${PATH}"
COPY . .
RUN site/build.sh site/dist https://bend-kit.paymahn.workers.dev && bend site/server.bend -o site/out/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libssl3 python3 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /app /app
RUN useradd --system --uid 10001 site
USER site
EXPOSE 8080
CMD ["sh", "-c", "exec site/out/server +RTS --threads 1 --gpu off -RTS 8080 . https://bend-kit.paymahn.workers.dev $(scripts/packages.sh)"]
