FROM ghcr.io/linuxserver/baseimage-alpine:3.21

LABEL maintainer="aptalca"

ENV ATTACHED_DEVICES_PERMS="/ -regex \/dev\/.*st[0-9]"

RUN \
  echo "**** install runtime packages ****" && \
  apk add --no-cache --upgrade \
    logrotate \
    mt-st \
    screen \
    tar && \
  echo "**** fix logrotate ****" && \
  sed -i "s#/var/log/messages {}.*# #g" /etc/logrotate.conf && \
  sed -i 's,/usr/sbin/logrotate /etc/logrotate.conf,/usr/sbin/logrotate /etc/logrotate.conf -s /config/logrotate.status,g' \
    /etc/periodic/daily/logrotate && \
  rm -rf \
    /tmp/*

# add local files
COPY /root /
