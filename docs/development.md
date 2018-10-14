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
