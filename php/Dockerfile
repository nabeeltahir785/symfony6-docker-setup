FROM php:8.1.1-fpm
ARG USER_EMAIL
ARG USER_NAME
ENV GIT_EMAIL=$USER_EMAIL \
    GIT_NAME=$USER_NAME
RUN echo $GIT_EMAIL
RUN apt update \
    && apt install -y zlib1g-dev g++ git libicu-dev zip libzip-dev zip \
    && apt-get install -y libpq-dev \
    && docker-php-ext-install intl opcache pdo pdo_mysql  pdo_pgsql \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && docker-php-ext-configure zip \
    && docker-php-ext-install zip

WORKDIR /var/www/symfony_docker

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN curl -sS https://get.symfony.com/cli/installer | bash
RUN mv /root/.symfony5/bin/symfony /usr/local/bin/symfony
RUN git config --global user.email "$GIT_EMAIL" \
    && git config --global user.name "$GIT_NAME"