FROM ubuntu:20.04 AS builder
LABEL maintainer Naba Das <hello@get-deck.com>
LABEL Author="Naba Das" Description="A comprehensive docker image to run Apache-2.4 PHP-7.4 applications like Wordpress, Laravel, etc"


# Stop dpkg-reconfigure tzdata from prompting for input
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ondrej/php

# Install apache and php7
RUN apt-get update && \
    apt-get -y install \
        apache2 \
        apache2-utils \
        php7.4 \
        php7.4-bcmath \
        php7.4-dev \
        php7.4-cli \
        php7.4-curl \
        php7.4-mbstring \
        php7.4-gd \
        php7.4-mysql \
        php7.4-json \
        php7.4-ldap \
        php7.4-memcached \
        php7.4-pgsql \
        php7.4-tidy \
        php7.4-intl \
        php7.4-xmlrpc \
        php7.4-soap \
        php7.4-uploadprogress \
        php7.4-zip \
        php7.4-mongodb \
        git \
        sudo 
# Ensure apache can bind to 80 as non-root
    RUN apt install -y libcap2-bin procps
    RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2ctl 

# UID and GID change
    ARG USER_ID
    ARG GROUP_ID
    RUN usermod -u ${USER_ID} www-data && groupmod -g ${GROUP_ID} www-data
    
# As apache is never run as root, change dir ownership
    RUN chown -R www-data:www-data /usr/sbin/apache2
    RUN chown -R www-data:www-data /var/log/apache2
    RUN chown -R www-data:www-data /var/run/apache2
    RUN chown -R www-data:www-data /etc/apache2
# Install ImageMagick CLI tools
    RUN apt-get update && apt-get -y install --no-install-recommends imagemagick
# Setup apache
    RUN a2enmod rewrite && \
        a2enmod headers

# Override default apache and php config
COPY src/apache2.conf /etc/apache2/apache2.conf
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
RUN echo "www-data ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
# Clean up apt setup files
    RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# Reload config without restarting apache
    # sudo /etc/init.d/apache2 reload

FROM ubuntu:20.04
COPY --from=builder / /
WORKDIR /var/www

EXPOSE 80
USER www-data

ENTRYPOINT ["apache2ctl", "-D", "FOREGROUND"]
