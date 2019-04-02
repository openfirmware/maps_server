#########
## Locale
#########
default['maps_server']['locale'] = 'en_CA'

##################################
## Installation Directory Prefixes
##################################
# For software packages
default['maps_server']['software_prefix'] = '/opt'
# For map source data downloads
default['maps_server']['data_prefix'] = '/srv/data'
# For map stylesheets
default['maps_server']['stylesheets_prefix'] = '/srv/stylesheets'

##################
## Extract Sources
##################
# If extract date is set and any existing extract is older, then
# A) a new extract will be downloaded
# B) the local OSM database will be reloaded
# C) The database will be re-vacuumed after import
# D) stylesheet-specific indexes will be created again
# Date should be ISO8601 with a timezone. Leave as nil or empty string
# to ignore.
# For extract URLs, use PBF files only.
default['maps_server']['extracts'] = [{
  'extract_date_requirement' => '2018-11-30T11:00:00+01:00',
  'extract_url'              => 'https://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf',
  'extract_checksum_url'     => 'https://download.geofabrik.de/north-america/canada/alberta-latest.osm.pbf.md5'
}, {
  'extract_date_requirement' => '2018-11-30T11:00:00+01:00',
  'extract_url'              => 'https://download.geofabrik.de/north-america/canada/saskatchewan-latest.osm.pbf',
  'extract_checksum_url'     => 'https://download.geofabrik.de/north-america/canada/saskatchewan-latest.osm.pbf.md5'
}]
# Crop the extract to a given bounding box
# Use a blank array or nil for no crop
# Order is the same as used by osm2pgsql:
# min longitude, min latitude, max longitude,
# max latitude
default['osm2pgsql']['crop_bounding_box'] = []
# default['osm2pgsql']['crop_bounding_box'] = [-115, 50, -113, 52]

# OSM2PGSQL Node Cache Size in Megabytes
# Default is 800 MB.
default['osm2pgsql']['node_cache_size'] = 1600

# Number of processes to use for osm2pgsql import.
# Should match number of threads/cores.
default['osm2pgsql']['import_procs'] = 12

#################
## Rendering User
#################
default['maps_server']['render_user'] = 'render'

###################################
## Default Location for Web Clients
###################################
# This location is Calgary, Canada
default['maps_server']['viewers']['latitude'] = 51.0452
default['maps_server']['viewers']['longitude'] = -114.0625
default['maps_server']['viewers']['zoom'] = 4

####################################
## PostgreSQL Original Configuration
####################################
#
# Adding more options will require editing 
# templates/default/postgresql.conf.erb
default['postgresql']['conf']['data_directory'] = '/var/lib/postgresql/11/main'
default['postgresql']['conf']['hba_file'] = '/etc/postgresql/11/main/pg_hba.conf'
default['postgresql']['conf']['ident_file'] = '/etc/postgresql/11/main/pg_ident.conf'
default['postgresql']['conf']['external_pid_file'] = '/var/run/postgresql/11-main.pid'

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

default['postgresql']['conf']['wal_level'] = 'replica'
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

# Some of these logging parameters could be used to analyze the
# performance of the database by using a tool like pgbadger. But they
# also generate a very large log file.
default['postgresql']['conf']['log_min_duration_statement'] = -1
default['postgresql']['conf']['log_checkpoints'] = 'off'
default['postgresql']['conf']['log_connections'] = 'off'
default['postgresql']['conf']['log_disconnections'] = 'off'
default['postgresql']['conf']['log_error_verbosity'] = 'default'
default['postgresql']['conf']['log_line_prefix'] = '%t [%p]: %q%u@%d '
default['postgresql']['conf']['log_lock_waits'] = 'off'
default['postgresql']['conf']['log_temp_files'] = -1
default['postgresql']['conf']['log_timezone'] = 'UTC'
default['postgresql']['conf']['cluster_name'] = '11/main'

default['postgresql']['conf']['stats_temp_directory'] = '/var/run/postgresql/11-main.pg_stat_tmp'

default['postgresql']['conf']['autovacuum'] = 'on'
default['postgresql']['conf']['log_autovacuum_min_duration'] = -1

default['postgresql']['conf']['datestyle'] = 'iso, mdy'
default['postgresql']['conf']['timezone'] = 'UTC'
default['postgresql']['conf']['lc_messages'] = 'en_US.utf8'
default['postgresql']['conf']['lc_monetary'] = 'en_US.utf8'
default['postgresql']['conf']['lc_numeric'] = 'en_US.utf8'
default['postgresql']['conf']['lc_time'] = 'en_US.utf8'
default['postgresql']['conf']['default_text_search_config'] = 'pg_catalog.english'

default['postgresql']['conf']['include_dir'] = 'conf.d'

##################################
## PostgreSQL Import Configuration
##################################
#
# Do not set too high: https://github.com/openstreetmap/osm2pgsql/issues/163
# But up to 32GB should be fine: http://thebuild.com/blog/2017/06/09/shared_buffers-is-not-a-sensitive-setting/
# 25% of max RAM is okay.
default['postgresql']['import-conf']['shared_buffers'] = '2GB'
default['postgresql']['import-conf']['temp_buffers'] = '64MB'
default['postgresql']['import-conf']['work_mem'] = '64MB'

# Can be high because it only runs during a single session vacuum:
# https://www.postgresql.org/docs/11/static/runtime-config-resource.html
default['postgresql']['import-conf']['maintenance_work_mem'] = '2GB'
default['postgresql']['import-conf']['autovacuum_work_mem'] = '4GB'

# See https://www.postgresql.org/docs/11/static/runtime-config-resource.html
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

# Use a larger maximum WAL Size for bulk data loading
default['postgresql']['import-conf']['max_wal_size'] = '4GB'

# If using SSDs, then random reads are MUCH more efficient than spinning HDDs
# and the query planner should be told this
default['postgresql']['import-conf']['random_page_cost'] = 1.1

# See https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
default['postgresql']['import-conf']['effective_cache_size'] = '6GB'

# Larger values help query planning
default['postgresql']['import-conf']['default_statistics_target'] = 500

# Do not autovacuum during imports, it can be done afterwards
default['postgresql']['import-conf']['autovacuum'] = 'off'

#######################################
## PostgreSQL Tile Server Configuration
#######################################
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
# https://www.postgresql.org/docs/11/static/runtime-config-resource.html
default['postgresql']['tile-conf']['maintenance_work_mem'] = '2GB'
default['postgresql']['tile-conf']['autovacuum_work_mem'] = -1

# See https://www.postgresql.org/docs/11/static/runtime-config-resource.html
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

