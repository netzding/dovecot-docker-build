ARG ALPINE_TAG=latest
FROM alpine:${ALPINE_TAG} AS build
RUN apk add --no-cache shadow ca-certificates curl coreutils automake autoconf g++ libtool expat-dev make libressl-dev libcap-dev json-c-dev libbz2 lz4-dev xz-dev zlib postgresql-dev mariadb-dev sqlite-dev openldap-dev krb5-dev heimdal-libs cmake git

## build dovecot
RUN mkdir -p /opt/build/
RUN curl -o dovecot.tar.gz https://www.dovecot.org/releases/2.3/dovecot-2.3.4.tar.gz
RUN tar -xzvf dovecot.tar.gz -C /opt/build
WORKDIR /opt/build/dovecot-2.3.4/
RUN ./configure -prefix=/opt/dovecot/ --with-ssl=openssl --with-lz4 --with-lzma --with-libcap --with-sql=plugin --with-pgsql --with-mysql --with-sqlite --with-ldap=plugin --with-solr --with-gssapi=plugin --with-rundir=/run/dovecot --localstatedir=/var --sysconfdir=/etc && make
RUN make install

## build Pigeonhole
WORKDIR /opt/build
RUN curl -o pigeonhole.tar.gz https://pigeonhole.dovecot.org/releases/2.3/dovecot-2.3-pigeonhole-0.5.4.tar.gz
RUN tar -xzvf pigeonhole.tar.gz -C /opt/build
WORKDIR /opt/build/dovecot-2.3-pigeonhole-0.5.4
RUN ./configure -prefix=/opt/dovecot/ --with-dovecot=/opt/build/dovecot-2.3.4/ --with-ldap=plugin && make
RUN make install

## build fts-elasticsearch plugin
WORKDIR /opt/build
RUN git clone https://github.com/atkinsj/fts-elasticsearch.git
WORKDIR /opt/build/fts-elasticsearch
RUN ./autogen.sh
RUN ./configure -prefix=/opt/dovecot/ --with-dovecot=/opt/build/dovecot-2.3.4/ && make
RUN make install

## build xaps-plugin
WORKDIR /opt/build
RUN git clone https://github.com/st3fan/dovecot-xaps-plugin.git
RUN mkdir /opt/build/dovecot-xaps-plugin/build
WORKDIR /opt/build/dovecot-xaps-plugin/build
RUN ln -s /opt/dovecot/include/dovecot /usr/include/dovecot
RUN git checkout tags/v0.6
RUN cmake .. -DCMAKE_BUILD_TYPE=Release -DLIBDOVECOT=/opt/dovecot/include/dovecot -DLIBDOVECOTSTORAGE=/opt/dovecot/include/dovecot
RUN make install

RUN find /opt/dovecot/ -name '*.la' | xargs rm -f

FROM alpine:latest
RUN apk add --update --no-cache shadow ca-certificates libcap expat mariadb-connector-c libpq sqlite-libs
COPY --from=build /opt/dovecot/ /opt/dovecot/
COPY --from=build /usr/lib/dovecot/modules/ /opt/dovecot/lib/dovecot/
ENV PATH="/opt/dovecot/bin:${PATH}"
ENV PATH="/opt/dovecot/sbin:${PATH}"
RUN groupadd -g 5000 vmail
RUN useradd -r -u 5000 -g vmail vmail
RUN groupadd -g 2525 postfix
RUN useradd -r -u 2525 -g postfix postfix
RUN groupadd -g 2500 dovecot
RUN groupadd -g 2501 dovenull
RUN useradd -r -M -d /opt/dovecot/lib/dovecot -s /bin/false -g dovecot dovecot
RUN useradd -r -M -d /nonexistent -s /bin/false -g dovenull dovenull
ENTRYPOINT ["dovecot", "-F"]