FROM golang:1.14.15-alpine3.13 AS Builder

RUN echo "Asia/Shanghai" > /etc/timezone

RUN apk add --no-cache build-base curl

ARG DRONE_VERSION=2.6.0

WORKDIR /src

# Build with online code
RUN curl -L https://ghproxy.com/https://github.com/drone/drone/archive/refs/tags/v${DRONE_VERSION}.tar.gz -o v${DRONE_VERSION}.tar.gz && \
    tar zxvf v${DRONE_VERSION}.tar.gz && rm v${DRONE_VERSION}.tar.gz

WORKDIR /src/drone-${DRONE_VERSION}

RUN go mod download

#ENV CGO_CFLAGS="-g -O2 -Wno-return-local-addr"

RUN go build -ldflags "-extldflags \"-static\"" -tags="nolimit" github.com/drone/drone/cmd/drone-server



FROM alpine:3.11 AS Certs
RUN echo "Asia/Shanghai" > /etc/timezone
RUN apk add -U --no-cache ca-certificates



FROM alpine:3.11
EXPOSE 80 443
VOLUME /data

RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

ENV GODEBUG netdns=go
ENV XDG_CACHE_HOME /data
ENV DRONE_DATABASE_DRIVER sqlite3
ENV DRONE_DATABASE_DATASOURCE /data/database.sqlite
ENV DRONE_RUNNER_OS=linux
ENV DRONE_RUNNER_ARCH=amd64
ENV DRONE_SERVER_PORT=:80
ENV DRONE_SERVER_HOST=localhost
ENV DRONE_DATADOG_ENABLED=false
ENV DRONE_DATADOG_ENDPOINT=https://example.com/

ARG DRONE_VERSION=2.6.0

COPY --from=Certs /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=Builder /src/drone-${DRONE_VERSION}/drone-server /bin/drone-server
ENTRYPOINT ["/bin/drone-server"]