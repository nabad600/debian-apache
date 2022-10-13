FROM debian:buster
#
# Step 1: Installation
#

# System environments
ENV DEBIAN_FRONTEND="noninteractive" \
    LOCALE="es_ES.UTF-8" \
    GOTPL_VER="0.1.5"

# Set repositories
RUN \
  echo "deb http://ftp.de.debian.org/debian/ buster main non-free contrib" > /etc/apt/sources.list && \
  echo "deb-src http://ftp.de.debian.org/debian/ buster main non-free contrib" >> /etc/apt/sources.list && \
  echo "deb http://security.debian.org/ buster/updates main contrib non-free" >> /etc/apt/sources.list && \
  echo "deb-src http://security.debian.org/ buster/updates main contrib non-free" >> /etc/apt/sources.list && \
  apt-get -qq update && apt-get -qqy upgrade && \
# Install some basic tools needed for deployment
  apt-get -yqq install \
  apt-utils \
  build-essential \
  debconf-utils \
  debconf \
  default-mysql-client \
  locales \
  curl \
  wget \
  unzip \
  patch \
  rsync \
  vim \
  nano \
  openssh-client \
  git \
  bash-completion \
  locales \
  libjpeg-turbo-progs libjpeg-progs \
  pngcrush optipng && \
# Install locale
  sed -i -e "s/# $LOCALE/$LOCALE/" /etc/locale.gen && \
  echo "LANG=$LOCALE">/etc/default/locale && \
  dpkg-reconfigure --frontend=noninteractive locales && \
  update-locale LANG=$LOCALE && \
# GOTPL
  gotpl_url="https://github.com/wodby/gotpl/releases/download/${GOTPL_VER}/gotpl-linux-amd64-${GOTPL_VER}.tar.gz"; \
  wget -qO- "${gotpl_url}" | tar xz -C /usr/local/bin; \
# Configure Sury sources
# @see https://www.noobunbox.net/serveur/auto-hebergement/installer-php-7-1-sous-debian-et-ubuntu
  apt-get -yqq install apt-transport-https lsb-release ca-certificates && \
  wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg && \
  echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list && \
# Install PHP7 with Xdebug (dev environment)
  apt-get -qq update && \
  apt-get -yqq install \
  php8.0 		\
  php8.0-bcmath   \
  php8.0-bz2   \
  php8.0-curl 		\
  php8.0-dev 		\
  php8.0-gd 		\
  php8.0-dom		\
  php8.0-imap     \
  php8.0-intl 		\
  php8.0-ldap 		\
  php8.0-mbstring	\
  php8.0-mysql		\
  php8.0-oauth		\
  php8.0-odbc		\
  php8.0-xml		\
  php8.0-yaml		\
  php8.0-zip		\
  php8.0-solr		\
  php8.0-apcu		\
  php8.0-opcache	\
  php8.0-redis		\
  php8.0-memcache 	\
  php8.0-xdebug		\
  php8.0-mongodb \
  libapache2-mod-php8.0 && \
# Install SMTP.
  apt-get -yqq install libgnutls-openssl27 && \
  wget ftp.de.debian.org/debian/pool/main/s/ssmtp/ssmtp_2.64-8+b2_amd64.deb && \
  dpkg -i ssmtp_2.64-8+b2_amd64.deb && rm ssmtp_2.64-8+b2_amd64.deb && \
# Install Apache web server.
  apt-get -yqq install apache2 && \
  apt install -y sudo && \
#
# Step 2: Configuration
#
# Enable uploadprogress, imagick, redis and solr.
  phpenmod uploadprogress imagick redis solr && \
# Disable by default apcu, apcu_bc, opcache, xdebug and xhprof. Use docker-compose.yml to add file.
  phpdismod apcu apcu_bc opcache xdebug xhprof && \
# Remove all sites enabled
# RUN rm /etc/apache2/sites-enabled/*
# Configure needed apache modules and disable default site
# mpm_worker enabled.
  a2dismod mpm_event cgi && \
  a2enmod		\
  access_compat		\
  actions		\
  alias			\
  auth_basic		\
  authn_core		\
  authn_file		\
  authz_core		\
  authz_groupfile	\
  authz_host 		\
  authz_user		\
  autoindex		\
  dir			\
  env 			\
  expires 		\
  filter 		\
  headers		\
  mime 			\
  negotiation 		\
  php8.0 		\
  mpm_prefork 		\
  reqtimeout 		\
  rewrite 		\
  setenvif 		\
  status 		\
  ssl && \
# without the following line we get "AH00558: apache2: Could not reliably determine the server's fully qualified domain name"
# autorise .htaccess files
  sed -i '/<Directory \/var\/www\/>/,/<\/Directory>/ s/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf && \
# Install composer (latest version) | prestissimo to speed up composer
  cd /tmp && \
  curl -sS https://getcomposer.org/installer -o composer-setup.php && \
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
# Step 3: Clean the system
#
# Cleanup some things.
  apt-get -q autoclean && \
  rm -rf /var/lib/apt/lists/*
# UID and GID change
  ARG USER_ID
  ARG GROUP_ID
  RUN usermod -u ${USER_ID} www-data && groupmod -g ${GROUP_ID} www-data
# Setup apache
  RUN a2enmod rewrite && \
  a2enmod headers
# Install XDEBUG
    ARG XDEBUG
    RUN if [ ${XDEBUG} = true ]; then \
    echo "zend_extension=xdebug" >> /etc/php/8.0/cli/php.ini \
    ;fi

# Configure templates
WORKDIR /var/www/
COPY templates /etc/gotpl/
COPY scripts/apache2-foreground /usr/bin/
RUN chown -R www-data:www-data /usr/sbin/apache2 && \
  chown -R www-data:www-data /var/log/apache2 && \
  chown -R www-data:www-data /var/run/apache2 && \
  chown -R www-data:www-data /etc/apache2 && \
  chown -R www-data:www-data /etc/ssmtp && \
  chown -R www-data:www-data /etc/php/8.0/apache2
EXPOSE 80
RUN echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER www-data
CMD ["apache2-foreground"]
