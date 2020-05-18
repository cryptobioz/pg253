# Build exporter
FROM centos:7 AS builder

WORKDIR /usr/src/
ADD https://www.python.org/ftp/python/3.7.5/Python-3.7.5.tgz  /usr/src/
RUN yum -y install curl make gcc openssl-devel bzip2-devel libffi-devel
RUN tar xzf Python-3.7.5.tgz && \
    rm -fr Python-3.7.5.tgz && \
    cd Python-3.7.5 && \
    ./configure --prefix=/usr --enable-optimizations --enable-shared && \
    make install -j 8 && \
    cd .. && \
    rm -fr Python-3.7.5 && \
    ldconfig && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py

COPY requirements.txt /usr/src/
RUN pip3 install -r requirements.txt
RUN pip3 install pyinstaller
ADD pg253 /usr/src/
ADD main.py /usr/src/
RUN pyinstaller --onefile main.py && \
    mv dist/main pg253-master

# Build final image
FROM postgres:12

COPY --from=builder /usr/src/pg253-master /usr/bin/pg253
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    apt-get upgrade -y -q && \
    apt-get dist-upgrade -y -q && \
    apt-get -y -q autoclean && \
    apt-get -y -q autoremove
ENTRYPOINT ["/usr/bin/pg253"]