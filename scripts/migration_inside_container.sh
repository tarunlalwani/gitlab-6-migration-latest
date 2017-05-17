#!/bin/bash

echo "Dropping current tables"
echo "select 'DROP table ' || tablename || ' CASCADE;'  from pg_tables  WHERE schemaname='public';" | gitlab-rails db | head -n -2 | tail -n +3 | gitlab-rails db

echo "Dropping current sequences"
echo "select 'DROP SEQUENCE ' || sequence_name || ';'  from information_schema.sequences  WHERE NOT sequence_schema IN ('pg_catalog', 'information_schema') and sequence_schema='public' and sequenc    e_catalog='gitlabhq_production';" | gitlab-rails db | head -n -2 | tail -n +3 | gitlab-rails db

echo "Loading current database"
cat /db/database.sql | gitlab-rails db

echo "Updating permissions"
update-permissions

echo "Reconfigure gitlab"
gitlab-ctl reconfigure

echo "Restart gitlab"
gitlab-ctl restart

MIGRATION_COUNT=0

run_migrations() {
    ((MIGRATION_COUNT++))
    echo "Running migration $MIGRATION_COUNT"
    gitlab-rake db:migrate 2>&1 | tee -a /tmp/migration.log | grep -A9 ERROR
}

run_migrations

echo "Fixing issues.deleted_at migration issue"
echo "ALTER TABLE issues add column deleted_at timestamp;" | gitlab-rails db

run_migrations

echo "Fixing projects.pending_delete migration issue"
echo "ALTER TABLE projects add column pending_delete boolean;" | gitlab-rails db

run_migrations

echo "Fixing nilClass migration issue"
gitlab-rake gitlab:db:mark_migration_complete[20140729152420]


run_migrations
echo "Fixing projects.pending_delete migration issue"
echo "ALTER TABLE projects DROP COLUMN pending_delete;" | gitlab-rails db


run_migrations
echo "Fixing issues.deleted_at migration issue"
echo "ALTER TABLE issues DROP COLUMN deleted_at ;" | gitlab-rails db

run_migrations

echo "Checking issues"
gitlab-rake gitlab:check

echo "Setting up SSH KEYS"
LC_ALL=en_US.UTF-8 gitlab-rake gitlab:shell:setup
