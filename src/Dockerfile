FROM amazonlinux
RUN yum -y makecache
RUN yum -y update
RUN yum -y install python3 zip mysql
RUN mkdir /build
WORKDIR /src
RUN cp /usr/bin/mysqldump ./
COPY *.py *.sql ./
RUN zip -r /build/release.zip .
