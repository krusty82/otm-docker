
FROM ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive

# install deps
RUN apt-get update && \
    apt-get install -y \
    sudo \
    devscripts \
    debhelper \
    libjson-perl \
    libipc-sharelite-perl \
    libgd-perl \
    git \
    build-essential \
    python \
    zlib1g-dev \
    clang \
    make \
    pkg-config \
    curl \
    libmapnik3.0 \
    libmapnik-dev \
    mapnik-utils \
    python-mapnik python3-mapnik \
    unifont \
    letsencrypt \
    wget \
    python3-certbot \
    python3-certbot-apache \
    openssh-server \
    postgresql postgresql-10-postgis-2.4 \
    apache2 autoconf apache2-dev \
    cmake libbz2-dev libgeos-dev libpq-dev libproj-dev lua5.3 liblua5.3-dev \
    rsyslog nano \
    gdal-bin \
    screen \
    pyhgtmap \
    python-setuptools python3-matplotlib python-beautifulsoup python3-numpy python3-bs4 python3-gdal python-gdal

# install locale so that postgres db is created with utf-8
RUN apt-get install --yes locales && \
    locale-gen --no-purge en_US.UTF-8 && \
    update-locale LANG=en_US.UTF-8  && \
    echo locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8 | debconf-set-selections  && \
    echo locales locales/default_environment_locale select en_US.UTF-8 | debconf-set-selections  && \
    dpkg-reconfigure locales

# install tirex (at commit 9c52ce1 which was in March 2020)
RUN git clone https://github.com/geofabrik/tirex /home/tirex && \
    cd /home/tirex && git checkout 9c52ce1 && make && make deb && cd /home && \
    dpkg -i tirex-core_0.6.1_amd64.deb && \
    dpkg -i tirex-backend-mapnik_0.6.1_amd64.deb && \
    dpkg -i tirex-syncd_0.6.1_amd64.deb

# install apache & mod_tile (at commit fd5988f)
RUN git clone https://github.com/openstreetmap/mod_tile.git /home/mod_tile && \
    cd /home/mod_tile && git checkout fd5988f && echo '/etc/renderd.conf' > debian/renderd.conffiles && debuild -i -b -us -uc && \
    dpkg -i /home/libapache2-mod-tile_0.4-12~precise2_amd64.deb && \
    mkdir /mnt/tiles && rm -rf /var/lib/tirex/tiles && rm -rf /var/lib/mod_tile && ln -s /mnt/tiles /var/lib/tirex/tiles && ln -s /mnt/tiles /var/lib/mod_tile

# install stuff for letsencrypt
# This is not supported anymore. Deactivating for now.
# RUN cd /usr/local/bin && wget https://dl.eff.org/certbot-auto && chmod a+x certbot-auto

# Install osm2pgsql from source (at commit 7892613)
RUN	mkdir ~/osm2pgsql && cd ~/osm2pgsql && \
	git clone https://github.com/openstreetmap/osm2pgsql.git && \
	cd osm2pgsql && git checkout 7892613 && \
	mkdir build && cd build && \
	cmake .. && \
	make && \
	make install && \
	rm -rf osm2pgsql


RUN dpkg -i /home/tirex-example-map_0.6.1_amd64.deb

# install phyghtmap
RUN wget http://katze.tfiu.de/projects/phyghtmap/phyghtmap_2.21-1_all.deb && \
    dpkg -i phyghtmap_2.21-1_all.deb

# set python3 to be the default
RUN echo "alias python=python3" >>~/.bashrc

# install python-downloader & oogle drive downloader
RUN apt-get install -y python3-pip && pip3 install gdown

# install nik4.py
RUN wget -O /usr/local/bin/nik4.py https://raw.githubusercontent.com/Zverik/Nik4/master/nik4.py && chmod 755 /usr/local/bin/nik4.py

# copy assets
COPY assets /

# enable apache modules (depends on copied assets)
RUN a2dismod mpm_event && a2enmod mpm_prefork headers tile proxy proxy_http proxy_balancer ssl rewrite

ENV LC_ALL=en_US.UTF-8
ENV LETSENCRYPT=0
ENV EMAIL=admin@localserver.net
ENV DOMAIN=otm-docker.example.io
ENV WHITELIST=127.0.0.1
ENV MOD_TILE_PREVENT_EXPIRATION=0

# start anything
EXPOSE 80
EXPOSE 443
ENTRYPOINT ["/usr/local/bin/startup.sh"]
