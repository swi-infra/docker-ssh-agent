# The MIT License
#
#  Copyright (c) 2015, CloudBees, Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

FROM eclipse-temurin:21-jdk AS jdk

# Python 2 is needed on the agent by the 'repo' tool (sierra branch, '#!/usr/bin/env python2'),
# but bookworm doesn't package it. Build it under /opt/python2 against OpenSSL 1.1.1, as
# Python 2.7's ssl module doesn't support bookworm's OpenSSL 3.
FROM debian:bookworm AS python2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG PYTHON2_VERSION=2.7.18
ARG PYTHON2_SHA256=da3080e3b488f648a3d7a4560ddee895284c3380b11d6de75edb986526b9a814
ARG OPENSSL11_VERSION=1.1.1w
ARG OPENSSL11_SHA256=cf3098950cb4d853ad95c0841f1f9c6d3dc102dccfcacd521d93925208b76ac8
RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential ca-certificates curl perl \
                          zlib1g-dev libbz2-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*
RUN ( \
      cd /tmp && \
      curl -fsSLo openssl.tar.gz https://github.com/openssl/openssl/releases/download/OpenSSL_${OPENSSL11_VERSION//./_}/openssl-${OPENSSL11_VERSION}.tar.gz && \
      echo "${OPENSSL11_SHA256}  openssl.tar.gz" | sha256sum -c - && \
      tar xzf openssl.tar.gz && cd openssl-${OPENSSL11_VERSION} && \
      ./config --prefix=/opt/python2 --openssldir=/etc/ssl --libdir=lib shared && \
      make -j"$(nproc)" && make install_sw && \
      cd /tmp && \
      curl -fsSLo python.tgz https://www.python.org/ftp/python/${PYTHON2_VERSION}/Python-${PYTHON2_VERSION}.tgz && \
      echo "${PYTHON2_SHA256}  python.tgz" | sha256sum -c - && \
      tar xzf python.tgz && cd Python-${PYTHON2_VERSION} && \
      ./configure --prefix=/opt/python2 --enable-unicode=ucs4 --with-ensurepip=no \
                  CPPFLAGS="-I/opt/python2/include" \
                  LDFLAGS="-L/opt/python2/lib -Wl,-rpath,/opt/python2/lib" && \
      make -j"$(nproc)" && make install && \
      /opt/python2/bin/python2 -c "import ssl, hashlib, zlib, bz2, json, ctypes; print(ssl.OPENSSL_VERSION)" && \
      rm -rf /opt/python2/lib/python2.7/test /opt/python2/lib/*.a /opt/python2/share /opt/python2/include \
             /opt/python2/bin/openssl /opt/python2/bin/c_rehash /tmp/* \
    )

FROM debian:bookworm
LABEL maintainer="Central Engineering <central-eng@semtech.com>"

# Temurin only ships Ubuntu-based images, so take the JDK from it
ENV JAVA_HOME=/opt/java/openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"
COPY --from=jdk /opt/java/openjdk ${JAVA_HOME}

COPY --from=python2 /opt/python2 /opt/python2
# 'python' is Python 2 as well, like in the previous Debian 9 image
RUN ln -sf /opt/python2/bin/python2.7 /usr/bin/python2.7 \
    && ln -sf python2.7 /usr/bin/python2 \
    && ln -sf python2 /usr/bin/python

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG JENKINS_AGENT_HOME=/home/${user}

ENV JENKINS_AGENT_HOME=${JENKINS_AGENT_HOME}

RUN groupadd -g ${gid} ${group} \
    && useradd -d "${JENKINS_AGENT_HOME}" -u "${uid}" -g "${gid}" -m -s /bin/bash "${user}"

# Keep umask 022 for SSH sessions: with pam_umask, USERGROUPS_ENAB turns it into 002
# for jenkins:jenkins, which makes the sudoers.d bind-mounted into encaps group-writable
RUN sed -i 's/^USERGROUPS_ENAB.*/USERGROUPS_ENAB no/' /etc/login.defs

# Setup SSH server
RUN apt-get update \
    && apt-get install --no-install-recommends -y openssh-server \
    && rm -rf /var/lib/apt/lists/*
RUN sed -i /etc/ssh/sshd_config \
        -e 's/#PermitRootLogin.*/PermitRootLogin no/' \
        -e 's/#RSAAuthentication.*/RSAAuthentication yes/'  \
        -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/#SyslogFacility.*/SyslogFacility AUTH/' \
        -e 's/#LogLevel.*/LogLevel INFO/' && \
    mkdir /var/run/sshd

COPY setup-sshd /usr/local/bin/setup-sshd

# Add java to default PATH
RUN ln -sf $(which java) /usr/bin/java

EXPOSE 22

# Install few tools
RUN ( \
      apt-get update && \
      apt-get -y install git git-lfs net-tools python3 bzip2 lbzip2 unzip netcat-openbsd rsync wget \
                         apt-transport-https ca-certificates curl gnupg2 software-properties-common \
                         iproute2 iputils-ping && \
      install -m 0755 -d /etc/apt/keyrings && \
      curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
      chmod a+r /etc/apt/keyrings/docker.gpg && \
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo $VERSION_CODENAME) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
      apt-get update && \
      apt-get -y install docker-ce && \
      rm -rf /var/lib/apt/lists/* && \
      usermod -a -G docker "${user}" && \
      # Docker socket gids used on the hosts; reuse the group if the gid is already taken
      for g in 233:docker2 998:docker3 122:docker4; do \
        gid=${g%%:*}; name=$(getent group "$gid" | cut -d: -f1); \
        [ -n "$name" ] || { name=${g#*:}; groupadd -g "$gid" "$name"; }; \
        usermod -a -G "$name" "${user}"; \
      done \
      )

# Groups/users from the previous Debian 9 image; encaps containers bind-mount this
# /etc/passwd and /etc/group, and their dpkg statoverride entries reference them.
# Created after the docker groups so the fixed docker gids above stay free.
RUN for g in crontab ssh Debian-exim systemd-bus-proxy; do groupadd -r -f "$g"; done \
    && for u in Debian-exim systemd-bus-proxy; do \
         id -u "$u" >/dev/null 2>&1 || useradd -r -M -g "$u" -d /nonexistent -s /usr/sbin/nologin "$u"; \
       done

# bash as default shell: Jenkins "Execute shell" steps run /bin/sh and use bash syntax.
# bookworm's dash dropped the "dash/sh" debconf switch, so point /bin/sh at bash directly
# (/bin is a symlink to /usr/bin on bookworm)
RUN ln -sf bash /usr/bin/sh

# Add Tini
ENV TINI_VERSION=v0.18.0
RUN mkdir -p /opt/tini
RUN ( \
    wget https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) \
    -O /opt/tini/tini \
)
RUN chmod +x /opt/tini/tini

# custom jq with support for --rawfile
RUN curl -fsSL https://github.com/swi-infra/jq/releases/download/v0.2.8/jq-$(dpkg --print-architecture) -o /usr/bin/jq && \
    chmod +x /usr/bin/jq
VOLUME /opt/tini
ENTRYPOINT ["/opt/tini/tini", "--", "/usr/local/bin/setup-sshd"]

# Add encaps
RUN ( \
        cd /usr/bin && \
        wget https://github.com/swi-infra/jenkins-docker-encaps/archive/master.zip && \
        unzip master.zip && \
        mv jenkins-docker-encaps-master/encaps* . && \
        rm -rf master.zip jenkins-docker-encaps-master \
    )

# Add Agent
ARG VERSION=3355.v388858a_47b_33
RUN ( \
        curl --create-dirs -fsSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
        && chmod 755 /usr/share/jenkins \
        && chmod 644 /usr/share/jenkins/slave.jar \
        && ln -sf /usr/share/jenkins/slave.jar /home/jenkins/remoting.jar \
    )

VOLUME "${JENKINS_AGENT_HOME}" "/tmp" "/run" "/var/run"
WORKDIR "${JENKINS_AGENT_HOME}"
