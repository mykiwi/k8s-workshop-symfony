FROM node:9.11 as node

WORKDIR /var/www/html
COPY package.json yarn.lock /var/www/html/
RUN yarn install

FROM php:7.2-apache

WORKDIR /var/www/html
RUN a2enmod rewrite && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        coreutils \
        curl \
        git \
        libcurl4-openssl-dev \
        libicu-dev \
        libjpeg-dev \
        libpng-dev \
        libsqlite3-dev \
        libxml2-dev \
        openssl \
        openssh-client \
        unzip && \
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt-/lists/* && \
    docker-php-ext-configure \
        gd --with-jpeg-dir=/usr/local && \
    docker-php-ext-install -j$(nproc) \
        bcmath \
        curl \
        gd \
        iconv \
        intl \
        json \
        mbstring \
        opcache \
        pdo_sqlite \
        xml \
        zip

COPY docker/apache/vhost.conf /etc/apache2/sites-available/000-default.conf

COPY composer.json composer.lock symfony.lock /var/www/html/
ENV COMPOSER_ALLOW_SUPERUSER 1 \
    COMPOSER_HOME /tmp
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm composer-setup.php && \
    composer install --optimize-autoloader --no-dev --no-scripts --no-progress

COPY --from=node /var/www/html/node_modules/ /var/www/html/node_modules/
COPY . /var/www/html/

ENV APP_ENV=prod \
    APP_SECRET=67d829bf61dc5f87a73fd814e2c9f629 \
    DATABASE_URL="sqlite:////var/www/html/var/blog.sqlite" \
    MAILER_URL=null://localhost \
    REDIS_URL=redis://localhost

RUN composer dump-autoload --classmap-authoritative --no-dev && \
    composer run-script post-install-cmd --no-dev && \
    rm -rf var/cache/* && \
    APP_ENV=prod bin/console cache:warmup && \
    bin/console doctrine:database:create --no-interaction && \
    bin/console doctrine:schema:create --no-interaction && \
    bin/console doctrine:fixtures:load --no-interaction && \
    chown -R www-data:www-data /var/www/html
