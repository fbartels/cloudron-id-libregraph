# ==========
# build base
# ==========
FROM stabletec/build-core:ubuntu-20.04 AS libregraph-builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build args
ARG EXTRA_PACKAGES=

# Noninteractive for package manager.
ENV DEBIAN_FRONTEND noninteractive

# Lang for tests.
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# Install buildtime dependencies.
RUN apt-get update -y \
	&& apt-get install -y --no-install-recommends \
		${EXTRA_PACKAGES} \
		ant ant-contrib \
		binutils \
		chrpath \
		curl \
		gettext \
		libarchive-dev \
		libev-dev \
		libgumbo-dev \
		libspf2-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-utils \
		libz-dev \
		php \
		php-gd \
		php-xml \
		pkg-config \
		python \
		python3.8 \
		ruby-full \
		software-properties-common \
		unzip \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=2.1.5

# Install golang
RUN add-apt-repository ppa:longsleep/golang-backports --yes && \
	apt-get install -y --no-install-recommends \
		golang-go && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Install Node, we use v16 which is/will be LTS from october 2021 till april 2024
RUN curl -sL https://deb.nodesource.com/setup_16.x -o nodesource_setup.sh && \
	bash nodesource_setup.sh && \
	apt-get install nodejs && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Install Yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
	echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
	apt-get update \
	&& apt-get install -y --no-install-recommends \
		yarn \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Set working directory.
ENV WORKSPACE=/build
WORKDIR ${WORKSPACE}

# ====
# kweb
# ====
FROM libregraph-builder AS kweb

COPY kweb/ /build
ARG KWEB_VERSION
RUN VERSION=$KWEB_VERSION make DATE=reproducible

# ==================
# LibreGraph Connect
# ==================
FROM libregraph-builder AS lico

COPY lico/ /build
ARG LICO_VERSION
RUN VERSION=$LICO_VERSION make DATE=reproducible all dist
RUN mkdir -p /opt/libregraph/lico
RUN tar -C /opt/libregraph/lico --strip 1 -vxzf dist/*.tar.gz

# ==============
# LibreGraph IDM
# ==============
FROM libregraph-builder AS idm

COPY idm/ /build
ARG IDM_VERSION
RUN VERSION=$IDM_VERSION make DATE=reproducible all dist
RUN mkdir -p /opt/libregraph/idm
RUN tar -C /opt/libregraph/idm --strip 1 -vxzf dist/*.tar.gz

# ===========
# Other tools
# ===========

# ===========
# final stage
# ===========
FROM cloudron/base:3.0.0@sha256:455c70428723e3a823198c57472785437eb6eab082e79b3ff04ea584faf46e92 as cloudron-id

WORKDIR /app/data

EXPOSE 2015

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install step cli for certificate management
ENV STEPCLI_VERSION=0.17.7 \
	STEPCERT_VERSION=0.17.6
RUN wget https://github.com/smallstep/cli/releases/download/v"$STEPCLI_VERSION"/step-cli_"$STEPCLI_VERSION"_amd64.deb && \
	wget https://github.com/smallstep/certificates/releases/download/v"$STEPCERT_VERSION"/step-ca_"$STEPCERT_VERSION"_amd64.deb && \
	dpkg -i step-*_amd64.deb && \
	rm step-*_amd64.deb

RUN wget https://github.com/ghostunnel/ghostunnel/releases/download/v1.6.0/ghostunnel-v1.6.0-linux-amd64 \
	-O /usr/local/bin/ghosttunnel && \
	chmod +x /usr/local/bin/ghosttunnel

COPY --from=idm /opt/libregraph /opt/libregraph
COPY --from=lico /opt/libregraph /opt/libregraph
COPY --from=kweb /build/bin/kwebd /usr/local/bin/
RUN ln -sf /opt/libregraph/idm/idmd /usr/local/bin/idmd

# add supervisor configs
RUN sed -e 's,^logfile=.*$,logfile=/run/supervisord.log,' -i /etc/supervisor/supervisord.conf
COPY supervisor/* /etc/supervisor/conf.d/

COPY config/Caddyfile /etc/Caddyfile
COPY bin/* /usr/local/bin/
COPY start.sh /app/pkg/

ARG IDM_VERSION
LABEL com.github.libregraph.lico=$IDM_VERSION
ARG LICO_VERSION
LABEL com.github.libregraph.lico=$LICO_VERSION
ARG KWEB_VERSION
LABEL com.github.libregraph.kweb=$KWEB_VERSION
ARG VCS_REF
LABEL org.opencontainers.image.revision=$VCS_REF
RUN \
	echo "IDM_VERSION=$IDM_VERSION" >> /app/pkg/.version && \
	echo "LICO_VERSION=$LICO_VERSION" >> /app/pkg/.version && \
	echo "KWEB_VERSION=$KWEB_VERSION" >> /app/pkg/.version
CMD [ "/app/pkg/start.sh" ]