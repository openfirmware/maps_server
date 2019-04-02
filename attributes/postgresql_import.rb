##################################
## PostgreSQL Import Configuration
##################################
#
# Do not set too high: https://github.com/openstreetmap/osm2pgsql/issues/163
# But up to 32GB should be fine: http://thebuild.com/blog/2017/06/09/shared_buffers-is-not-a-sensitive-setting/
# 25% of max RAM is okay.
default[:postgresql][:settings][:import][:shared_buffers] = "4GB"
default[:postgresql][:settings][:import][:temp_buffers] = "64MB"
default[:postgresql][:settings][:import][:work_mem] = "64MB"

# Can be high because it only runs during a single session vacuum:
# https://www.postgresql.org/docs/11/static/runtime-config-resource.html
default[:postgresql][:settings][:import][:maintenance_work_mem] = "2GB"
default[:postgresql][:settings][:import][:autovacuum_work_mem] = "4GB"

# See https://www.postgresql.org/docs/11/static/runtime-config-resource.html
# Use 0 if you have spinning hard disks and not SSDs.
# Use the same Queue Depth as your storage device.
default[:postgresql][:settings][:import][:effective_io_concurrency] = 200

# fsync isn"t as necessary as the data can be completely rebuilt.
default[:postgresql][:settings][:import][:fsync] = "off"
default[:postgresql][:settings][:import][:synchronous_commit] = "off"
default[:postgresql][:settings][:import][:full_page_writes] = "off"

# See https://www.postgresql.org/docs/current/static/runtime-config-wal.html
default[:postgresql][:settings][:import][:wal_buffers] = "16MB"
default[:postgresql][:settings][:import][:checkpoint_completion_target] = 0.9

# Use a larger maximum WAL Size for bulk data loading
default[:postgresql][:settings][:import][:max_wal_size] = "4GB"

# If using SSDs, then random reads are MUCH more efficient than spinning HDDs
# and the query planner should be told this
default[:postgresql][:settings][:import][:random_page_cost] = 1.1

# See https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
default[:postgresql][:settings][:import][:effective_cache_size] = "12GB"

# Larger values help query planning
default[:postgresql][:settings][:import][:default_statistics_target] = 500

# Do not autovacuum during imports, it can be done afterwards
default[:postgresql][:settings][:import][:autovacuum] = "off"
