## Locale
default['maps_server']['locale'] = 'en_CA'

## Installation Directory Prefixes
# For software packages
default['maps_server']['software_prefix'] = '/opt'
# For map source data downloads
default['maps_server']['data_prefix'] = '/srv/data'
# For map stylesheets
default['maps_server']['stylesheets_prefix'] = '/srv/stylesheets'

## Extract Source
# Use PBF files only
default['maps_server']['extract_url'] = 'http://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf'
default['maps_server']['extract_checksum_url'] = 'http://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf.md5'

## Rendering User
default['maps_server']['render_user'] = 'render'

## PostgreSQL Original Configuration
#
# Adding more options will require editing 
# templates/default/postgresql.conf.erb
default['postgresql']['conf']['data_directory'] = '/var/lib/postgresql/10/main'
default['postgresql']['conf']['hba_file'] = '/etc/postgresql/10/main/pg_hba.conf'
default['postgresql']['conf']['ident_file'] = '/etc/postgresql/10/main/pg_ident.conf'
default['postgresql']['conf']['external_pid_file'] = '/var/run/postgresql/10-main.pid'

default['postgresql']['conf']['listen_addresses'] = 'localhost'
default['postgresql']['conf']['port'] = 5432
default['postgresql']['conf']['max_connections'] = 100
default['postgresql']['conf']['unix_socket_directories'] = '/var/run/postgresql'
default['postgresql']['conf']['ssl'] = 'on'
default['postgresql']['conf']['ssl_cert_file'] = '/etc/ssl/certs/ssl-cert-snakeoil.pem'
default['postgresql']['conf']['ssl_key_file'] = '/etc/ssl/private/ssl-cert-snakeoil.key'

default['postgresql']['conf']['shared_buffers'] = '128MB'
default['postgresql']['conf']['temp_buffers'] = '8MB'
default['postgresql']['conf']['work_mem'] = '4MB'
default['postgresql']['conf']['maintenance_work_mem'] = '64MB'
default['postgresql']['conf']['autovacuum_work_mem'] = -1
default['postgresql']['conf']['dynamic_shared_memory_type'] = 'posix' 
default['postgresql']['conf']['effective_io_concurrency'] = 1
default['postgresql']['conf']['max_worker_processes'] = 8
default['postgresql']['conf']['max_parallel_workers_per_gather'] = 2
default['postgresql']['conf']['max_parallel_workers'] = 8

default['postgresql']['conf']['fsync'] = 'on'
default['postgresql']['conf']['synchronous_commit'] = 'on'
default['postgresql']['conf']['wal_sync_method'] = 'fsync'
default['postgresql']['conf']['full_page_writes'] = 'on'
default['postgresql']['conf']['wal_buffers'] = -1
default['postgresql']['conf']['checkpoint_timeout'] = '5min'
default['postgresql']['conf']['max_wal_size'] = '1GB'
default['postgresql']['conf']['min_wal_size'] = '80MB'
default['postgresql']['conf']['checkpoint_completion_target'] = 0.5

default['postgresql']['conf']['random_page_cost'] = 4.0
default['postgresql']['conf']['cpu_tuple_cost'] = 0.01
default['postgresql']['conf']['effective_cache_size'] = '4GB'
default['postgresql']['conf']['default_statistics_target'] = 100

default['postgresql']['conf']['log_line_prefix'] = '%m [%p] %q%u@%d '
default['postgresql']['conf']['log_timezone'] = 'UTC'
default['postgresql']['conf']['cluster_name'] = '10/main'

default['postgresql']['conf']['stats_temp_directory'] = '/var/run/postgresql/10-main.pg_stat_tmp'

default['postgresql']['conf']['autovacuum'] = 'on'

default['postgresql']['conf']['datestyle'] = 'iso, mdy'
default['postgresql']['conf']['timezone'] = 'UTC'
default['postgresql']['conf']['lc_messages'] = 'en_US.utf8'
default['postgresql']['conf']['lc_monetary'] = 'en_US.utf8'
default['postgresql']['conf']['lc_numeric'] = 'en_US.utf8'
default['postgresql']['conf']['lc_time'] = 'en_US.utf8'
default['postgresql']['conf']['default_text_search_config'] = 'pg_catalog.english'

default['postgresql']['conf']['include_dir'] = 'conf.d'

## PostgreSQL Import Configuration
#
# Do not set too high: https://github.com/openstreetmap/osm2pgsql/issues/163
# But up to 32GB should be fine: http://thebuild.com/blog/2017/06/09/shared_buffers-is-not-a-sensitive-setting/
# 25% of max RAM is okay.
default['postgresql']['import-conf']['shared_buffers'] = '2GB'
default['postgresql']['import-conf']['temp_buffers'] = '64MB'
default['postgresql']['import-conf']['work_mem'] = '64MB'

# Can be high because it only runs during a single session vacuum:
# https://www.postgresql.org/docs/10.5/static/runtime-config-resource.html
default['postgresql']['import-conf']['maintenance_work_mem'] = '2GB'
default['postgresql']['import-conf']['autovacuum_work_mem'] = '4GB'

# See https://www.postgresql.org/docs/9.6/static/runtime-config-resource.html
# Use 0 if you have spinning hard disks and not SSDs.
# Use the same Queue Depth as your storage device.
default['postgresql']['import-conf']['effective_io_concurrency'] = 32

# fsync isn't as necessary as the data can be completely rebuilt.
default['postgresql']['import-conf']['fsync'] = 'off'
default['postgresql']['import-conf']['synchronous_commit'] = 'off'
default['postgresql']['import-conf']['full_page_writes'] = 'off'

# See https://www.postgresql.org/docs/current/static/runtime-config-wal.html
default['postgresql']['import-conf']['wal_buffers'] = '16MB'
default['postgresql']['import-conf']['checkpoint_completion_target'] = 0.9

# If using SSDs, then random reads are MUCH more efficient than spinning HDDs
# and the query planner should be told this
default['postgresql']['import-conf']['random_page_cost'] = 1.1

# See https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
default['postgresql']['import-conf']['effective_cache_size'] = '6GB'

# Larger values help query planning
default['postgresql']['import-conf']['default_statistics_target'] = 500

# Do not autovacuum during imports, it can be done afterwards
default['postgresql']['import-conf']['autovacuum'] = 'off'

## PostgreSQL Tile Server Configuration
# 
# More connections are needed when pre-rendering many tiles simultaneously
default['postgresql']['tile-conf']['max_connections'] = 300

# Do not set too high: https://github.com/openstreetmap/osm2pgsql/issues/163
# But up to 32GB should be fine: http://thebuild.com/blog/2017/06/09/shared_buffers-is-not-a-sensitive-setting/
# 25% of max RAM is okay.
default['postgresql']['tile-conf']['shared_buffers'] = '2GB'
default['postgresql']['tile-conf']['temp_buffers'] = '64MB'
default['postgresql']['tile-conf']['work_mem'] = '64MB'

# Can be high because it only runs during a single session vacuum:
# https://www.postgresql.org/docs/10.5/static/runtime-config-resource.html
default['postgresql']['tile-conf']['maintenance_work_mem'] = '2GB'
default['postgresql']['tile-conf']['autovacuum_work_mem'] = -1

# See https://www.postgresql.org/docs/9.6/static/runtime-config-resource.html
# Use 0 if you have spinning hard disks and not SSDs.
# Use the same Queue Depth as your storage device.
default['postgresql']['tile-conf']['effective_io_concurrency'] = 32

# fsync isn't as necessary as the data can be completely rebuilt.
default['postgresql']['tile-conf']['fsync'] = 'off'
default['postgresql']['tile-conf']['synchronous_commit'] = 'off'
default['postgresql']['tile-conf']['full_page_writes'] = 'off'

# See https://www.postgresql.org/docs/current/static/runtime-config-wal.html
default['postgresql']['tile-conf']['wal_buffers'] = '16MB'
default['postgresql']['tile-conf']['checkpoint_completion_target'] = 0.9

# If using SSDs, then random reads are MUCH more efficient than spinning HDDs
# and the query planner should be told this
default['postgresql']['tile-conf']['random_page_cost'] = 1.1

# See https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
default['postgresql']['tile-conf']['effective_cache_size'] = '6GB'

# Larger values help query planning
default['postgresql']['tile-conf']['default_statistics_target'] = 500

default['postgresql']['tile-conf']['autovacuum'] = 'on'