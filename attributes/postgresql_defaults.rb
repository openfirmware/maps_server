####################################
## PostgreSQL Original Configuration
####################################
#
# Adding more options will require editing 
# templates/default/postgresql.conf.erb
default[:postgresql][:settings][:defaults][:data_directory] = "/var/lib/postgresql/11/main"
default[:postgresql][:settings][:defaults][:hba_file] = "/etc/postgresql/11/main/pg_hba.conf"
default[:postgresql][:settings][:defaults][:ident_file] = "/etc/postgresql/11/main/pg_ident.conf"
default[:postgresql][:settings][:defaults][:external_pid_file] = "/var/run/postgresql/11-main.pid"

default[:postgresql][:settings][:defaults][:listen_addresses] = "localhost"
default[:postgresql][:settings][:defaults][:port] = 5432
default[:postgresql][:settings][:defaults][:max_connections] = 100
default[:postgresql][:settings][:defaults][:unix_socket_directories] = "/var/run/postgresql"
default[:postgresql][:settings][:defaults][:ssl] = "on"
default[:postgresql][:settings][:defaults][:ssl_cert_file] = "/etc/ssl/certs/ssl-cert-snakeoil.pem"
default[:postgresql][:settings][:defaults][:ssl_key_file] = "/etc/ssl/private/ssl-cert-snakeoil.key"

default[:postgresql][:settings][:defaults][:shared_buffers] = "128MB"
default[:postgresql][:settings][:defaults][:temp_buffers] = "8MB"
default[:postgresql][:settings][:defaults][:work_mem] = "4MB"
default[:postgresql][:settings][:defaults][:maintenance_work_mem] = "64MB"
default[:postgresql][:settings][:defaults][:autovacuum_work_mem] = -1
default[:postgresql][:settings][:defaults][:dynamic_shared_memory_type] = "posix" 
default[:postgresql][:settings][:defaults][:effective_io_concurrency] = 1
default[:postgresql][:settings][:defaults][:max_worker_processes] = 8
default[:postgresql][:settings][:defaults][:max_parallel_workers_per_gather] = 2
default[:postgresql][:settings][:defaults][:max_parallel_workers] = 8

default[:postgresql][:settings][:defaults][:wal_level] = "replica"
default[:postgresql][:settings][:defaults][:fsync] = "on"
default[:postgresql][:settings][:defaults][:synchronous_commit] = "on"
default[:postgresql][:settings][:defaults][:wal_sync_method] = "fsync"
default[:postgresql][:settings][:defaults][:full_page_writes] = "on"
default[:postgresql][:settings][:defaults][:wal_buffers] = -1
default[:postgresql][:settings][:defaults][:checkpoint_timeout] = "5min"
default[:postgresql][:settings][:defaults][:max_wal_size] = "1GB"
default[:postgresql][:settings][:defaults][:min_wal_size] = "80MB"
default[:postgresql][:settings][:defaults][:checkpoint_completion_target] = 0.5

default[:postgresql][:settings][:defaults][:random_page_cost] = 4.0
default[:postgresql][:settings][:defaults][:cpu_tuple_cost] = 0.01
default[:postgresql][:settings][:defaults][:effective_cache_size] = "4GB"
default[:postgresql][:settings][:defaults][:default_statistics_target] = 100

# Some of these logging parameters could be used to analyze the
# performance of the database by using a tool like pgbadger. But they
# also generate a very large log file.
default[:postgresql][:settings][:defaults][:log_min_duration_statement] = -1
default[:postgresql][:settings][:defaults][:log_checkpoints] = "off"
default[:postgresql][:settings][:defaults][:log_connections] = "off"
default[:postgresql][:settings][:defaults][:log_disconnections] = "off"
default[:postgresql][:settings][:defaults][:log_error_verbosity] = "default"
default[:postgresql][:settings][:defaults][:log_line_prefix] = "%t [%p]: %q%u@%d "
default[:postgresql][:settings][:defaults][:log_lock_waits] = "off"
default[:postgresql][:settings][:defaults][:log_temp_files] = -1
default[:postgresql][:settings][:defaults][:log_timezone] = "UTC"
default[:postgresql][:settings][:defaults][:cluster_name] = "11/main"

default[:postgresql][:settings][:defaults][:stats_temp_directory] = "/var/run/postgresql/11-main.pg_stat_tmp"

default[:postgresql][:settings][:defaults][:autovacuum] = "on"
default[:postgresql][:settings][:defaults][:log_autovacuum_min_duration] = -1

default[:postgresql][:settings][:defaults][:datestyle] = "iso, mdy"
default[:postgresql][:settings][:defaults][:timezone] = "UTC"
default[:postgresql][:settings][:defaults][:lc_messages] = "en_US.utf8"
default[:postgresql][:settings][:defaults][:lc_monetary] = "en_US.utf8"
default[:postgresql][:settings][:defaults][:lc_numeric] = "en_US.utf8"
default[:postgresql][:settings][:defaults][:lc_time] = "en_US.utf8"
default[:postgresql][:settings][:defaults][:default_text_search_config] = "pg_catalog.english"

default[:postgresql][:settings][:defaults][:include_dir] = "conf.d"
