FROM ruby:2.4.2-alpine3.6

COPY . /usr/src/app
WORKDIR /usr/src/app

RUN apk add --no-cache --virtual build-deps \
    g++ \
    libc-dev \
    make \
 && bundle install \
 && apk del build-deps
