FROM php:7.2.18-zts


RUN apt-get update \
    && apt-get install -y --no-install-recommends apt-utils \
    && apt-get install -y git-core
#    && apt-get install -y git-core build-essential autoconf

RUN git clone https://github.com/krakjoe/pthreads -b master /tmp/pthreads
RUN cd /tmp/pthreads \
    && phpize \
    && ./configure \
    && make \
    && make install

RUN docker-php-ext-configure /tmp/pthreads --enable-pthreads
RUN docker-php-ext-install /tmp/pthreads
RUN docker-php-ext-enable pthreads
RUN apt-get autoremove -y
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
