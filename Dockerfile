# Default Alpine edge rolling build. Rolling release; not FIPS certified.
FROM alpine:edge
LABEL org.opencontainers.image.title="sftp-alpine-edge"
ENV TZ=America/Chicago AUTO_UPDATE=suite DEFAULT_ADMIN=true
RUN apk update && apk upgrade --available && apk add --no-cache bash tini openssh-server openssh-client openssh-sftp-server \
  fail2ban rsyslog whois iptables nftables tzdata ca-certificates curl openssl \
  coreutils findutils grep sed gawk shadow util-linux procps iproute2 \
  && mkdir -p /defaults/sshd /defaults/fail2ban/jail.d /defaults/fail2ban/filter.d \
     /defaults/fail2ban/action.d /etc/rsyslog.d /var/run/sshd \
     /var/run/fail2ban /var/spool/rsyslog /config/log /opt/debug \
  && rm -f /etc/ssh/ssh_host_*key* \
  && command -v whois \
  && command -v sshd \
  && command -v openssl \
  && command -v fail2ban-client
RUN printf 'auth,authpriv.*\t/config/log/auth.log\n' > /etc/rsyslog.d/00-auth.conf
COPY defaults/sshd/ /defaults/sshd/
COPY defaults/fail2ban/ /defaults/fail2ban/
COPY entrypoint.sh /usr/local/bin/
COPY scripts/update-inplace.sh /usr/local/bin/update-inplace.sh
COPY scripts/validate-security.sh scripts/healthcheck.sh scripts/security-status.sh scripts/report-versions.sh scripts/periodic-update.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/*.sh && \
    /usr/local/bin/report-versions.sh build > /opt/debug/build-versions.txt 2>&1
VOLUME ["/config"]
EXPOSE 22
HEALTHCHECK --interval=30s --timeout=8s --start-period=30s --retries=3 CMD ["/usr/local/bin/healthcheck.sh"]
ENTRYPOINT ["/sbin/tini","--","/usr/local/bin/entrypoint.sh"]
