FROM buildpack-deps:jessie

MAINTAINER Graham Dumpleton <Graham.Dumpleton@gmail.com>

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake \
        less \
        libdb-dev \
        libexpat1-dev \
        libpcre++-dev \
        libtinfo-dev \
        locales \
        mime-support \
        pkg-config \
        rsync \
        vim \
    && rm -r /var/lib/apt/lists/*

RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8

COPY install.sh /tmp/build/install.sh

ENV NGHTTP2_VERSION=1.6.0 \
    APR_VERSION=1.5.2 \
    APR_UTIL_VERSION=1.5.4 \
    APACHE_VERSION=2.4.18 \
    NSS_WRAPPER_VERSION=1.1.2 \
    TINI_VERSION=0.8.4

RUN /tmp/build/install.sh

ENV PATH=/usr/local/apache/bin:$PATH
