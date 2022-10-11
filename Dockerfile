FROM ubuntu:20.04 AS builder
LABEL maintainer Naba Das <hello@get-deck.com>
LABEL Author="Naba Das" Description="A comprehensive docker image to run Apache-2.4 PHP-7.4 applications like Wordpress, Laravel, etc"


# Stop dpkg-reconfigure tzdata from prompting for input
ENV DEBIAN_FRONTEND=noninteractive

# Install apache and php7
RUN apt-get update && \
    apt-get -y install \
        apache2 \
        libapache2-mod-php \
        libapache2-mod-auth-openidc \
        php-bcmath \
        php-dev \
        php-cli \
        php-curl \
        php-mbstring \
        php-gd \
        php-mysql \
        php-json \
        php-ldap \
        php-memcached \
        php-mime-type \
        php-pgsql \
        php-tidy \
        php-intl \
        php-xmlrpc \
        php-soap \
        php-uploadprogress \
        php-zip \
        git \
# Ensure apache can bind to 80 as non-root
        libcap2-bin && \
    setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2 && \
    dpkg --purge libcap2-bin && \
    apt-get -y autoremove && \
# As apache is never run as root, change dir ownership
    a2disconf other-vhosts-access-log && \
    chown -Rh www-data. /var/run/apache2 && \
# Install ImageMagick CLI tools
    apt-get -y install --no-install-recommends imagemagick && \
    pecl install mongodb && \
    echo "extension=mongodb.so" >> `php --ini | grep "Loaded Configuration" | sed -e "s|.*:\s*||"` && \
# Setup apache
    a2enmod rewrite headers expires ext_filter

# Override default apache and php config
COPY src/000-default.conf /etc/apache2/sites-available
COPY src/mpm_prefork.conf /etc/apache2/mods-available
COPY src/status.conf      /etc/apache2/mods-available
COPY src/99-local.ini     /etc/php/7.4/apache2/conf.d

# Display error On or Off
    ARG DISPLAY_PHPERROR
    RUN if [ ${DISPLAY_PHPERROR} = true ]; then \
    echo "display_errors = On" >>  /etc/php/7.4/apache2/conf.d/99-local.ini \
    ;fi

# Install XDEBUG
    ARG XDEBUG
    RUN if [ ${XDEBUG} = true ]; then \
    apt update && apt install php-xdebug \
    && echo "zend_extension=xdebug" >> /etc/php/7.4/apache2/conf.d/99-local.ini \
    ;fi
RUN echo "extension=mongodb.so" >>  /etc/php/7.4/apache2/conf.d/99-local.ini
RUN cd /tmp && \
    curl -sS https://getcomposer.org/installer -o composer-setup.php && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Clean up apt setup files
    RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

FROM ubuntu:20.04
COPY --from=builder / /
WORKDIR /var/www

EXPOSE 80
USER www-data

ENTRYPOINT ["apache2ctl", "-D", "FOREGROUND"]
