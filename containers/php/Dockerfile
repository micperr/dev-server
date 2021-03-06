FROM php:7.3.5-fpm

ARG USER_ID
ARG GROUP_ID
ARG WORK_DIR

# Libraries
RUN apt-get update && apt-get install -y \
    git \
    gnupg \
    libpq-dev \
    libzip-dev \
    libicu-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libssh-dev \
    librabbitmq-dev \
    vim-tiny \
    xvfb \
    wkhtmltopdf \
    unzip

# PHP extensions
RUN docker-php-ext-configure zip --with-libzip
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/
RUN docker-php-ext-install -j$(nproc) \
    bcmath \
    gd \
    intl \
    opcache \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    sockets \
    zip

RUN git clone https://github.com/allegro/php-protobuf /tmp/protobuf \
        && cd /tmp/protobuf \
        && git checkout v0.12.3 \
        && phpize \
        && ./configure \
        && make \
        && make install

RUN docker-php-ext-configure /tmp/protobuf
RUN docker-php-ext-install /tmp/protobuf
RUN docker-php-ext-enable protobuf

# Pecl packages
RUN pecl install xdebug-2.7.1 amqp redis
RUN docker-php-ext-enable amqp
RUN docker-php-ext-enable redis


RUN apt-get autoremove -y
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Node & npm
# RUN curl -sL https://deb.nodesource.com/setup_8.x | bash
# RUN apt-get install -y nodejs

# Composer
ARG COMPOSER_HOME=${WORK_DIR}/.composer
RUN mkdir -p $COMPOSER_HOME
# && echo "{}" > $COMPOSER_HOME/composer.json
ENV COMPOSER_HOME $COMPOSER_HOME
RUN install -d -m 0755 -o www-data -g www-data $COMPOSER_HOME && \
    curl -sS https://getcomposer.org/installer | \
        php -- --install-dir=/usr/local/bin \
               --filename=composer && \
        chown -R www-data:www-data $COMPOSER_HOME


# PHPUnit
### 6
# RUN curl -L -o phpunit6 https://phar.phpunit.de/phpunit-6.phar
# RUN chmod +x phpunit6
# RUN mv phpunit6 /usr/local/bin/phpunit6
### 7
# RUN curl -L -o phpunit7 https://phar.phpunit.de/phpunit-7.phar
# RUN chmod +x phpunit7
# RUN cp phpunit7 /usr/local/bin/phpunit
# RUN mv phpunit7 /usr/local/bin/phpunit7
### 8
# RUN curl -L -o phpunit8 https://phar.phpunit.de/phpunit-8.phar
# RUN chmod +x phpunit8
# RUN mv phpunit8 /usr/local/bin/phpunit8


# Recreate www-data user and group and assign same IDs as the current host user has
# https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
RUN if [ ${USER_ID} -ne 0 ] && [ ${GROUP_ID} -ne 0 ]; then \
    userdel -f www-data &&\
    if getent group www-data ; then groupdel www-data; fi && \
    if getent group dialout ; then groupdel dialout; fi && \
    groupadd -g ${GROUP_ID} www-data &&\
    useradd -l -u ${USER_ID} -g www-data www-data && \
    install -d -m 0755 -o www-data -g www-data ${WORK_DIR} /var/log && \
    mkdir /var/logs && \
    chown --changes --silent --no-dereference --recursive \
          --from=33:33 ${USER_ID}:${GROUP_ID} \
        ${WORK_DIR} \
        $COMPOSER_HOME \
        /var/log \
;fi


RUN rm -r /var/www
# RUN rm -r ${WORK_DIR}/html
COPY php.ini /usr/local/etc/php/
ENV HOME=${WORK_DIR}
RUN echo '<?php phpinfo(); ?>' > /phpinfo.php
USER www-data
