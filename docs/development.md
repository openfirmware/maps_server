# Development

Here are some instructions for developing, changing, testing, and deploying updates for this cookbook.

## Test Kitchen

Install [Vagrant][] and [VirtualBox][].

Create the VMs. If arg is omitted, VMs will be created for all platform/suite combinations.

```terminal
$ kitchen create [INSTANCE|REGEXP|all]
```

Login to inspect the VM:

```terminal
$ kitchen login [INSTANCE|REGEXP|all]
```

Run the recipes on the VM:

```terminal
$ kitchen converge [INSTANCE|REGEXP|all]
```

Run specs/tests on the VM:

```terminal
$ kitchen verify [INSTANCE|REGEXP|all]
```

Destroy the VMs. Remember to do this to shut them down and save space.

```terminal
$ kitchen destroy [INSTANCE|REGEXP|all]
```

[Vagrant]: https://www.vagrantup.com
[VirtualBox]: https://www.virtualbox.org

### Caching

To avoid having to re-download shapefiles when re-creating VMs, try adding this to the `.kitchen.yml` file:

```yml
driver:
  synced_folders:
    - ["/Users/YOU/Library/Caches/vagrant/%{instance_name}", "/srv/data", "create: true"]
```

For MacOS, change `YOU` to your username. This will store them in a cache folder that will avoid Time Machine backups (if you use them). Windows/\*NIX users should find their own equivalent cache directory.

The shapefiles for `openstreetmap-carto` are approximately 800 MB, which is slow to re-download and a waste of bandwidth to continually re-download.
