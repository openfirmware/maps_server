#######################################
## PostgreSQL Tile Server Configuration
#######################################
# 
# More connections are needed when pre-rendering many tiles simultaneously
default[:postgresql][:settings][:tiles][:max_connections] = 300

# Do not set too high: https://github.com/openstreetmap/osm2pgsql/issues/163
# But up to 32GB should be fine: http://thebuild.com/blog/2017/06/09/shared_buffers-is-not-a-sensitive-setting/
# 25% of max RAM is okay.
default[:postgresql][:settings][:tiles][:shared_buffers] = "12GB"
default[:postgresql][:settings][:tiles][:temp_buffers] = "64MB"
default[:postgresql][:settings][:tiles][:work_mem] = "64MB"

# Can be high because it only runs during a single session vacuum:
# https://www.postgresql.org/docs/11/static/runtime-config-resource.html
default[:postgresql][:settings][:tiles][:maintenance_work_mem] = "2GB"
default[:postgresql][:settings][:tiles][:autovacuum_work_mem] = -1

# See https://www.postgresql.org/docs/11/static/runtime-config-resource.html
# Use 0 if you have spinning hard disks and not SSDs.
# Use the same Queue Depth as your storage device.
default[:postgresql][:settings][:tiles][:effective_io_concurrency] = 200

# fsync isn"t as necessary as the data can be completely rebuilt.
default[:postgresql][:settings][:tiles][:fsync] = "off"
default[:postgresql][:settings][:tiles][:synchronous_commit] = "off"
default[:postgresql][:settings][:tiles][:full_page_writes] = "off"

# See https://www.postgresql.org/docs/current/static/runtime-config-wal.html
default[:postgresql][:settings][:tiles][:wal_buffers] = "16MB"
default[:postgresql][:settings][:tiles][:checkpoint_completion_target] = 0.9

# If using SSDs, then random reads are MUCH more efficient than spinning HDDs
# and the query planner should be told this
default[:postgresql][:settings][:tiles][:random_page_cost] = 1.1

# See https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
default[:postgresql][:settings][:tiles][:effective_cache_size] = "18GB"

# Larger values help query planning
default[:postgresql][:settings][:tiles][:default_statistics_target] = 500

default[:postgresql][:settings][:tiles][:autovacuum] = "on"
