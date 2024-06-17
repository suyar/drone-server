FROM golang:1.14.15 as build

ENV DRONE_VERSION=2.24.0

WORKDIR /src

RUN curl -L https://github.com/harness/gitness/archive/refs/tags/v${DRONE_VERSION}.tar.gz -o v${DRONE_VERSION}.tar.gz \
    && tar zxvf v${DRONE_VERSION}.tar.gz \
    && rm v${DRONE_VERSION}.tar.gz \
    && cd gitness-${DRONE_VERSION} \
    && go build -ldflags "-extldflags \"-static\"" -tags "nolimit" -o /src/release/linux/amd64/drone-server github.com/drone/drone/cmd/drone-server


FROM alpine:3.19 as alpine
RUN apk add -U --no-cache ca-certificates tzdata


FROM alpine:3.19
EXPOSE 80 443
VOLUME /data

RUN if [[ ! -e /etc/nsswitch.conf ]] ; then echo 'hosts: files dns' > /etc/nsswitch.conf ; fi

ENV GODEBUG netdns=go
ENV XDG_CACHE_HOME /data
ENV DRONE_DATABASE_DRIVER sqlite3
ENV DRONE_DATABASE_DATASOURCE /data/database.sqlite
ENV DRONE_RUNNER_OS=linux
ENV DRONE_RUNNER_ARCH=amd64
ENV DRONE_SERVER_PORT=:80
ENV DRONE_SERVER_HOST=localhost
ENV DRONE_DATADOG_ENABLED=true
ENV DRONE_DATADOG_ENDPOINT=https://stats.drone.ci/api/v1/series

COPY --from=alpine /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=alpine /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=build /src/release/linux/amd64/drone-server /bin/

ENTRYPOINT ["/bin/drone-server"]