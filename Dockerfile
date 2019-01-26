ARG ALPINE_TAG=latest
FROM alpine:${ALPINE_TAG} AS build
RUN apk add --no-cache shadow ca-certificates curl coreutils autoconf g++ libtool make libressl-dev libcap-dev libbz2 lz4-dev xz-dev zlib postgresql-dev mariadb-dev sqlite-dev openldap-dev krb5-dev heimdal-libs cmake git
RUN mkdir -p /opt/build/
RUN curl -o dovecot.tar.gz https://www.dovecot.org/releases/2.3/dovecot-2.3.4.tar.gz
RUN tar -xzvf dovecot.tar.gz -C /opt/build
WORKDIR /opt/build/dovecot-2.3.4/
RUN ls -la /opt/build
RUN ./configure -prefix=/opt/dist/ --without-shared-libs --with-ssl=openssl --with-lz4 --with-lzma --with-libcap --with-sql=plugin --with-pgsql --with-mysql --with-sqlite --with-ldap=plugin --with-gssapi=plugin --with-rundir=/run/dovecot --localstatedir=/var --sysconfdir=/etc && make 
RUN make install
WORKDIR /opt/build
RUN git clone https://github.com/st3fan/dovecot-xaps-plugin.git
RUN mkdir /opt/build/dovecot-xaps-plugin/build
WORKDIR /opt/build/dovecot-xaps-plugin/build
RUN ln -s /opt/dist/include/dovecot /usr/include/dovecot
RUN git checkout tags/v0.6
RUN cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBDOVECOT=/opt/dist/include/dovecot -DLIBDOVECOTSTORAGE=/opt/dist/include/dovecot
RUN make install
RUN find /opt/dist/

FROM alpine:latest
RUN apk add --update --no-cache shadow ca-certificates libcap
COPY --from=build /opt/dist/ /usr/
RUN groupadd -g 5000 vmail
RUN useradd -r -u 5000 -g vmail vmail
RUN groupadd -g 2525 postfix
RUN useradd -r -u 2525 -g postfix postfix
ENTRYPOINT ["dovecot", "-F"]
