#! /bin/bash
SCRIPT="
CREATE ROLE scm LOGIN PASSWORD 'scm';
CREATE DATABASE scm OWNER scm ENCODING 'UTF8';

CREATE ROLE amon LOGIN PASSWORD 'amon_password';
CREATE DATABASE amon OWNER amon ENCODING 'UTF8';

CREATE ROLE rman LOGIN PASSWORD 'rman_password';
CREATE DATABASE rman OWNER rman ENCODING 'UTF8';

CREATE ROLE hive LOGIN PASSWORD 'hive_password';
CREATE DATABASE metastore OWNER hive ENCODING 'UTF8';

CREATE ROLE sentry LOGIN PASSWORD 'sentry_password';
CREATE DATABASE sentry OWNER sentry ENCODING 'UTF8';

CREATE ROLE nav LOGIN PASSWORD 'nav_password';
CREATE DATABASE nav OWNER nav ENCODING 'UTF8';

CREATE ROLE navms LOGIN PASSWORD 'navms_password';
CREATE DATABASE navms OWNER navms ENCODING 'UTF8';

ALTER DATABASE Metastore SET standard_conforming_strings = off;

"

echo -e $SCRIPT > tmp.sql

sudo -u postgres psql -f tmp.sql
/usr/share/cmf/schema/scm_prepare_database.sh postgresql scm scm scm
rm /etc/cloudera-scm-server/db.mgmt.properties
rm -f tmp.sql
