#!/bin/bash

  # need to install maven3
  wget http://ppa.launchpad.net/natecarlson/maven3/ubuntu/pool/main/m/maven3/maven3_3.2.1-0~ppa1_all.deb
  dpkg -i  maven3_3.2.1-0~ppa1_all.deb
  ln -s /usr/share/maven3/bin/mvn /usr/bin/mvn
  rm maven3_3.2.1-0~ppa1_all.deb

  # created user
  useradd -m dspace
  echo "dspace:admin"|chpasswd
  mkdir /dspace
  chown dspace /dspace

  #conf tomcat7 for dspace
  a=$(cat /etc/tomcat8/server.xml | grep -n "</Host>"| cut -d : -f 1 )
  sed -i "$((a-1))r /tmp/dspace_tomcat8.conf" /etc/tomcat8/server.xml

  mkdir /build
        chmod -R 770 /build
        cd /build
        wget https://github.com/DSpace/DSpace/releases/download/dspace-5.3/dspace-5.3-src-release.tar.gz
        tar -zxf dspace-5.3-src-release.tar.gz
        rm dspace-5.3-src-release.tar.gz
    
        cd /build/dspace-5.3-src-release
        package -Dmirage2.on=true
        #work around for AUFS related bug. https://github.com/QuantumObject/docker-dspace/issues/2
        mkdir /etc/ssl/private-copy; mv /etc/ssl/private/* /etc/ssl/private-copy/; rm -r /etc/ssl/private; mv /etc/ssl/private-copy /etc/ssl/private; chmod -R 0700 /etc/ssl/private; chown -R postgres /etc/ssl/private
        
    #conf database before build and installation of dspace
        POSTGRESQL_BIN=/usr/lib/postgresql/9.4/bin/postgres
        POSTGRESQL_CONFIG_FILE=/etc/postgresql/9.4/main/postgresql.conf
        
        mkdir -p /var/run/postgresql/9.4-main.pg_stat_tmp
        chown postgres /var/run/postgresql/9.4-main.pg_stat_tmp
        chgrp postgres /var/run/postgresql/9.4-main.pg_stat_tmp
        
        /sbin/setuser postgres $POSTGRESQL_BIN --single \
                --config-file=$POSTGRESQL_CONFIG_FILE \
              <<< "UPDATE pg_database SET encoding = pg_char_to_encoding('UTF8') WHERE datname = 'template1'" &>/dev/null

        /sbin/setuser postgres $POSTGRESQL_BIN --single \
                --config-file=$POSTGRESQL_CONFIG_FILE \
                  <<< "CREATE USER dspace WITH SUPERUSER;" &>/dev/null
        /sbin/setuser postgres $POSTGRESQL_BIN --single \
                --config-file=$POSTGRESQL_CONFIG_FILE \
                <<< "ALTER USER dspace WITH PASSWORD 'dspace';" &>/dev/null
                
        echo "local all dspace md5" >> /etc/postgresql/9.4/main/pg_hba.conf
        /sbin/setuser postgres /usr/lib/postgresql/9.4/bin/postgres -D  /var/lib/postgresql/9.4/main -c config_file=/etc/postgresql/9.4/main/postgresql.conf >>/var/log/postgresd.log 2>&1 &
        sleep 10s
        /sbin/setuser dspace createdb -U dspace -E UNICODE dspace 
        
        # build dspace and install
        cd /build/dspace-5.3-src-release/dspace/target/dspace-installer
        ant fresh_install
        chown tomcat8:tomcat8 /dspace -R
        killall postgres
        sleep 10s

  apt-get clean
  rm -rf /build
  rm -rf /tmp/* /var/tmp/*
  rm -rf /var/lib/apt/lists/*
