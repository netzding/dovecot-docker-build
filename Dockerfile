ARG ALPINE_TAG=latest
FROM alpine:${ALPINE_TAG} AS build
RUN apk add --no-cache shadow ca-certificates curl coreutils automake autoconf g++ libtool expat-dev make libressl-dev libcap-dev json-c-dev libbz2 lz4-dev xz-dev zlib postgresql-dev mariadb-dev sqlite-dev openldap-dev krb5-dev heimdal-libs cmake git

ARG DOVECOT_SRC_URL
ARG DOVECOT_DIR
ARG PIGEONHOLE_SRC_URL
ARG PIGEONHOLE_DIR
ARG XAPS_SRC_URL
ARG XAPS_GIT_TAG

## build dovecot
RUN mkdir -p /opt/build/
RUN curl -o dovecot.tar.gz ${DOVECOT_SRC_URL}
RUN tar -xzvf dovecot.tar.gz -C /opt/build
WORKDIR /opt/build/${DOVECOT_DIR}
RUN ./configure -prefix=/opt/dovecot/ --with-ssl=openssl --with-lz4 --with-lzma --with-libcap --with-sql=plugin --with-pgsql --with-mysql --with-sqlite --with-ldap=plugin --with-solr --with-gssapi=plugin --with-rundir=/run/dovecot --localstatedir=/var --sysconfdir=/etc && make
RUN make install

## build Pigeonhole
WORKDIR /opt/build
RUN curl -o pigeonhole.tar.gz ${PIGEONHOLE_SRC_URL}
RUN tar -xzvf pigeonhole.tar.gz -C /opt/build
WORKDIR /opt/build/${PIGEONHOLE_DIR}
RUN ./configure -prefix=/opt/dovecot/ --with-dovecot=/opt/build/${DOVECOT_DIR} --with-ldap=plugin && make
RUN make install

## build xaps-plugin
WORKDIR /opt/build
RUN git clone ${XAPS_SRC_URL} dovecot-xaps-plugin
RUN mkdir /opt/build/dovecot-xaps-plugin/build
WORKDIR /opt/build/dovecot-xaps-plugin/build
RUN ln -s /opt/dovecot/include/dovecot /usr/include/dovecot
RUN git checkout ${XAPS_GIT_TAG}
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
