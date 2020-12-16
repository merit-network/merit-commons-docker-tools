# Set the base image to Ubuntu
FROM ubuntu:xenial

# File Author / Maintainer
MAINTAINER Michael Gregorowicz <mike@mg2.org>
LABEL vendor="Detroit Collaboration Works, LLC" \
      description="MeritCommons Docker Image 1.0, includes all dependencies required to run MeritCommons" \
      io.meritcommons.is-beta="1" \
      io.meritcommons.breaks-rules="1"

#RUN echo " #### INSTALLING APT-CACHER PROXY IN /etc/apt/sources.list #### " && \
#  perl -pi -e 's/http:\/\/archive.ubuntu.com/http:\/\/192.168.0.218:3142\/archive.ubuntu.com/g' /etc/apt/sources.list

ADD vendor/ubuntu /tmp/meritcommons_ubuntu

RUN apt-get update && \
 apt-get install -y libterm-readline-gnu-perl libimage-magick-perl \
 libdbix-class-perl sphinxsearch libreadline5 libreadline-dev libpgm-5.2-0 libpgm-dev \
 libjson-xs-perl libsphinx-search-perl libyaml-perl libnet-ldap-perl \
 libfile-mimeinfo-perl libimage-exif-perl libcrypt-cbc-perl \
 libcrypt-blowfish-perl libio-interface-perl libuuid-tiny-perl \
 libhtml-truncate-perl libtie-ixhash-perl libdbd-mysql-perl \
 libev-perl libtext-csv-perl libmodule-util-perl libarray-utils-perl \
 libcrypt-x509-perl libxml-simple-perl libfile-finder-perl \
 libperl-critic-perl libtext-markdown-perl libdata-treedumper-perl \
 libtest-class-perl memcached libcache-memcached-fast-perl \
 postgresql-9.5 libdbd-pg-perl cpanminus libsodium18 libsodium-dev libxml2 libxml2-dev \
 libaio1 libaio-dev build-essential unzip net-tools rsync libmaxminddb-dev \
 rubygems ruby-dev colordiff vim-tiny && \
 dpkg -i /tmp/meritcommons_ubuntu/*.deb && \
 apt-get install -f -y && \
 rm -rf /tmp/meritcommons_ubuntu && \
 service postgresql stop && systemctl disable postgresql

ADD vendor/instant_client /tmp/instant_client
ADD vendor/perl_modules /tmp/perl_modules

RUN cpanm --notest Crypt::Sodium CryptX Number::Bytes::Human Date::Parse Mojolicious \
  Unix::Uptime DBIx::Class::Migration Mojo::Pg CGI XML::CanonicalizeXML Minion Perl::Tidy \
  ZMQ::LibZMQ3 WebService::Amazon::Route53 VM::EC2 Mojolicious::Plugin::AccessLog \
  CryptX Selenium::Remote::Driver DBIx::Class::QueryLog Log::Syslog::Fast Net::Netmask \
  Digest::CRC Mail::Sender@0.902 BSD::Resource Linux::Inotify2 XML::Writer CSS::Sass Struct::Compare \
  Term::ProgressBar Algorithm::Combinatorics IO::Prompt Mojo::Server::Morbo::Backend::Inotify \
  Math::Int128 MaxMind::DB::Metadata MaxMind::DB::Reader MaxMind::DB::Reader::Role::HasMetadata \
  MaxMind::DB::Reader::Role::Reader MaxMind::DB::Types MaxMind::DB::Reader::XS@1.000002 Devel::Cover \
  Bloomd::Client Markdent Term::Spinner::Color GraphQL Mojolicious::Plugin::GraphQL \
  /tmp/perl_modules/GraphQL-Plugin-Convert-DBIC-0.03.tar.gz && \
 gem install therubyracer less && \
 perl /tmp/instant_client/build_dbd_oracle.pl && \
 rm -rvf /tmp/instant_client && \
 rm -rvf /tmp/perl_modules

# let MeritCommons know we're using a new enough system
RUN mkdir /usr/share/perl5/MeritCommons && echo "package MeritCommons::System; \
our \$VERSION = 3.0; \
1;" > /usr/share/perl5/MeritCommons/System.pm

ADD vendor/nvm /tmp/nvm
ADD vendor/skel /tmp/skel

ENV HOME=/usr/local/meritcommons \
 PATH=/usr/local/meritcommons/meritcommons/script:/usr/lib/postgresql/9.5/bin:/usr/local/meritcommons/node_modules/.bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/local/meritcommons/bin \
 PGDATA=/usr/local/meritcommons/var/pgsql/data \
 NVM_DIR=/usr/local/meritcommons/.nvm

# create the MeritCommons user
RUN cd / && tar -xzvf /tmp/skel/best_ever_etc_skel.tar.gz && rm -rvf /tmp/skel && \
  echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen && \
  useradd -d /usr/local/meritcommons -s /bin/bash -c "MeritCommons User" -m meritcommons && \
  chown meritcommons /var/run/postgresql && \
  chown -R meritcommons /usr/local/meritcommons && \
  su - meritcommons -c '/tmp/nvm/install_node.sh' && \
  rm -rvf /tmp/nvm

RUN apt-get purge -y build-essential make gcc g++ binutils ruby-dev manpages libreadline-dev \
 libpgm-dev libsodium-dev libxml2-dev libaio-dev && \
 apt-get autoremove -y && \
 apt-get clean all -y

##################### INSTALLATION END #####################
