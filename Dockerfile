FROM php:8.2-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libcurl4-openssl-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libonig-dev \
        libpng-dev \
        libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        gd \
        mbstring \
        opcache \
        pdo_mysql \
        zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && a2enmod rewrite headers \
    && sed -ri 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf \
    && printf '%s\n' 'ServerName localhost' > /etc/apache2/conf-available/server-name.conf \
    && a2enconf server-name \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . /var/www/html
COPY docker/php.ini /usr/local/etc/php/conf.d/acg-faka.ini
COPY docker/entrypoint.sh /usr/local/bin/acg-faka-entrypoint

RUN mkdir -p \
        /usr/local/share/acg-faka/default-theme \
        /var/www/html/config \
        /var/www/html/kernel/Install \
        /var/www/html/assets/cache \
        /var/www/html/runtime \
    && cp -a /var/www/html/app/View/User/Theme/. /usr/local/share/acg-faka/default-theme/ \
    && chmod +x /usr/local/bin/acg-faka-entrypoint

EXPOSE 80

ENTRYPOINT ["acg-faka-entrypoint"]
CMD ["apache2-foreground"]
