# Dockerfile for bitcore-dash-insight

FROM ubuntu:xenial
MAINTAINER moocowmoo <moocowmoo@dash.org>
LABEL description="dockerized bitcore/insight"

# replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Set debconf to run non-interactively
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# update base
RUN apt-get update \
    && apt-get upgrade -y -q \
    && apt-get install -y -q \
        build-essential \
        curl \
        git \
        libzmq3-dev \
        python2.7 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && ln -s /usr/bin/python2.7 /usr/bin/python

# install dashd 12.1 compile prerequisites
RUN apt-get update \
    && apt-get install -y -q software-properties-common \
    && add-apt-repository ppa:bitcoin/bitcoin \
    && apt-get update \
    && apt-get install -y -q \
        automake \
        autotools-dev \
        bsdmainutils \
        build-essential \
        libboost-all-dev \
        libdb4.8-dev \
        libdb4.8++-dev \
        libevent-dev \
        libssl-dev \
        libtool \
        pkg-config \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# compile dashd 12.1
RUN cd /tmp \
    && git clone https://github.com/udjinm6/dash -b dashBitcore \
    && cd dash \
    && ./autogen.sh \
    && ./configure \
    && make

# install dashd 12.1
RUN cp /tmp/dash/src/{dashd,dash-cli} /usr/bin

# setup and switch to user bitcore
RUN /usr/sbin/useradd -s /bin/bash -m -d /bitcore bitcore \
  && chown bitcore:bitcore -R /bitcore
USER bitcore
ENV HOME /bitcore

# install npm/node
ENV NODE_VERSION 5.0.0
ENV NVM_VERSION 0.31.2
ENV NVM_DIR $HOME/.nvm
RUN curl https://raw.githubusercontent.com/creationix/nvm/v$NVM_VERSION/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# install bitcore-node
RUN cd $HOME \
    && source $NVM_DIR/nvm.sh \
    && nvm use v5.0.0 \
    && mkdir -p $HOME/.nvm/versions/node/v5.0.0/lib/node_modules/bitcore-node/bin \
    && ln -s /usr/bin/dashd $HOME/.nvm/versions/node/v5.0.0/lib/node_modules/bitcore-node/bin \
    && git clone https://github.com/snogcel/dash-node-jaxx \
    && cd dash-node-jaxx \
    && npm install \
    && $HOME/dash-node-jaxx/bin/bitcore-node create mynode -d ~/.bitcore/data \
    && cd mynode \
    && $HOME/dash-node-jaxx/bin/bitcore-node install https://github.com/snogcel/dash-api-jaxx

# remove bitcore installed dash files (incompatible with ubuntu 16 libs)
RUN cd $HOME/dash-node-jaxx/bin \
    && rm -rf dash* \
    && ln -s /usr/bin/dashd .

# build launch wrapper until I figure out how to source nvm envs through CMD
RUN cd $HOME/dash-node-jaxx/bin \
    && echo "#!/bin/bash" >> launch_bitcore-node.sh \
    && echo "source $NVM_DIR/nvm.sh" >> launch_bitcore-node.sh \
    && echo "cd /bitcore/dash-node-jaxx/mynode" >> launch_bitcore-node.sh \
    && echo "/bitcore/dash-node-jaxx/bin/bitcore-node start" >> launch_bitcore-node.sh \
    && chmod a+x launch_bitcore-node.sh

EXPOSE 3001

VOLUME ["$HOME/.bitcore"]

CMD ["/bitcore/dash-node-jaxx/bin/launch_bitcore-node.sh"]
