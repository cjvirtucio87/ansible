# cjvirtucio87's Ansible Playbooks

Playbooks for spinning up infrastructure for your machine, targetting `Ubuntu 20.04`.

## Usage

See the `init.sh` documentation header for more information.

## Troubleshooting

### WSL2

Some services may prevent `systemd` from working correctly, and aren't actually needed
for Ubuntu 20 on `WSL2`. For instance, [`multipathd.socket` isn't needed](https://github.com/arkane-systems/genie/issues/122#issuecomment-786656284). In that case, just disable the service(s) that
are mentioned in their docs or their [issues page](https://github.com/arkane-systems/genie/issues)
that may not may necessary.
