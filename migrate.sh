#!/bin/bash

set -ex

# Please update variables before running thi script 

export GITLAB_VERSION=8.11.11-ce.0
PREV_GITLAB_MYSQL_USER=root
PREV_GITLAB_MYSQL_PASSWORD=root
PREV_GITLAB_MYSQL_DBNAME=gitlab
PREV_GITLAB_REPO_PATH = /xyz/please/update/me

if [ ! -d "db" ]; then
	mkdir db
fi

echo "Dumping old database"
mysqldump --compatible=postgresql --default-character-set=utf8 -r db/gitlabhq_production_new.mysql --extended-insert=FALSE -u${PREV_GITLAB_MYSQL_USER} -p${PREV_GITLAB_MYSQL_PASSWORD} ${PREV_GITLAB_MYSQL_DBNAME}

if [ ! -d "mysql-postgresql-converter" ]; then
    git clone https://github.com/gitlabhq/mysql-postgresql-converter.git -b gitlab
fi

echo "Converting old DB to new postgres format"
python mysql-postgresql-converter/db_converter.py db/gitlabhq_production_new.mysql db/database.sql

echo "Pulling docker images for Gitlab version $GITLAB_VERSION"
docker-compose pull

echo "Starting Gitlab"
docker-compose up -d

echo "Sleeping for 120 seconds"
sleep 120

echo "Waiting for DB to get up"
# Wait for the DB to get up
docker-compose logs -f gitlab | grep -q 'autovacuum launcher started'

echo "Copying existing repositories"
cp -vr ${PREV_GITLAB_REPO_PATH} ./data/git-data/repositories

echo "Running Upgrade script inside container"
docker-compose exec gitlab /scripts/migration_inside_container.sh

echo "Running upgrade to the latest version of gitlab"
. upgrade.sh
