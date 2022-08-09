# [Choice] PHP version (use -bullseye variants on local arm64/Apple Silicon): 8, 8.1, 8.0, 7, 7.4, 7.3, 8-bullseye, 8.1-bullseye, 8.0-bullseye, 7-bullseye, 7.4-bullseye, 7.3-bullseye, 8-buster, 8.1-buster, 8.0-buster, 7-buster, 7.4-buster
ARG VARIANT="7.4"
ARG NODE_VERSION="16"
FROM node:${NODE_VERSION}-bullseye AS node
FROM php:${VARIANT}-apache-bullseye

# copies the node files into the PHP files
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/bin/node /usr/local/bin/node
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm

# Install MariaDB client
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y mariadb-client \ 
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y git zip unzip chromium xvfb

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Install php-mysql driver
RUN docker-php-ext-install mysqli pdo pdo_mysql

# Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# this is for webaudit to run
RUN mkdir /etc/pki && mkdir /etc/pki/tls && openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -keyout /etc/pki/tls/dkey.pem -out /etc/pki/tls/cert.pem -subj "/C=US/ST=Nebaska/L=Lincoln/O=UNL/CN=app.localhost.unl.edu"

# removes error "Invalid command 'RewriteEngine'" and allows ssl
RUN a2enmod rewrite && a2enmod ssl && a2enmod socache_shmcb && service apache2 restart

# changes the docroot so the domain points to the correct file
ARG DIRROOT="/var/www/html"
ARG DOCROOT="/www"
ENV APACHE_DOCUMENT_ROOT=${DIRROOT}${DOCROOT}
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# creates the the ssl certs and creates ENV vars to be used in the conf files
ENV APACHE_SSL_KEY="/etc/ssl/private/apache-selfsigned.key"
ENV APACHE_SSL_CRT="/etc/ssl/certs/apache-selfsigned.crt"
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ${APACHE_SSL_KEY} -out ${APACHE_SSL_CRT} -subj "/C=US/ST=Nebaska/L=Lincoln/O=UNL/CN=app.localhost.unl.edu"

# copies the conf files that apache will use
# do not copy them to sites-enabled since sites-available have symlinks
COPY apacheConf/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY apacheConf/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf

# enables ssl site and checks config
RUN a2ensite default-ssl.conf && apachectl configtest

WORKDIR ${DIRROOT}

# can't do this since mounting the volume in the docker compose will remove the files made here
# COPY ./composer.json ${DIRROOT}
# RUN composer install

# can't do this since mounting the volume in the docker compose will remove the files made here
# COPY ./package.json ${DIRROOT}
# RUN npm install

COPY . ${DIRROOT}