FROM alpine:latest
RUN apk add --no-cache openssl dovecot dovecot-pigeonhole-plugin shadow ca-certificates
RUN groupadd -g 5000 vmail
RUN useradd -r -u 5000 -g vmail vmail
RUN groupadd -g 2525 postfix
RUN useradd -r -u 2525 -g postfix postfix
ENTRYPOINT ["dovecot", "-F"]
