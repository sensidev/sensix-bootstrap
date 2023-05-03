Salt Pre-Bootstrap
===

Pre-provisioning Salt Master and Minions.

Spin your VPS (Virtual Private Server) / machines from your favourite cloud provider.

## Prerequisites

1. Ubuntu 20.04 LTS - VPS
2. Root SSH access to all your VPS / machines.
3. A Salt git repository with States, Pillars and Master configs.

This is how we structured ours, with a `salt` folder wrapper.

We hold Salt masters base configs in `salt/masters` - one of these templates are used to configure salt master. 

```
├── salt
│   ├── masters
│   │   ├── dev.yml
│   │   └── prod.yml
│   ├── pillar
│   └── states
```

Example of `salt/masters/dev.yml`. The script will create a symlink from the salt repo to the `/etc/salt/master.d/`

```
log_level: debug
pillar_merge_lists: True
auto_accept: True
top_file_merging_strategy: same
pillar_safe_render_error: False

fileserver_backend:
  - roots

file_roots:
  base:
    - /path/to/salt/states

pillar_roots:
  base:
    - /path/to/salt/pillar
```

## Minimum hardware requirements

- 4 virtual CPUs
- 8 GB RAM
- 75 GB SSD storage

## Create keys

On your machine, create your own pair of ssh keys with `ssh-keygen`.
We recommend to have one for each machine, and handle them in `~/.ssh/config`.

The public key will be used later in the process, so you can SSH into your VPS.

We configure sshd service during the `install.sh` so you won't be able to SSH with root or using passwords, afterwards.

## Prepare VPS for provisioning
 
**SSH into your VPS, with root password**

Example.

`ssh -o IdentitiesOnly=yes root@<SERVERI_IP>`

Download public Pre-Bootstrap script:

```
wget -O install.sh https://raw.githubusercontent.com/sensidev/sensix-bootstrap/main/install.sh
```

Prepare environment variables for `install.sh`. Pick one that is appropriate for your current VPS machine from below.

## Examples of env var preparation

To install a **production salt master**, you must have in your git salt repository a salt master config template.
See: [examples/prod_master.sh](examples/prod_master.sh)

To install a **production salt minion** see [examples/prod_minion.sh](examples/prod_minion.sh)

To install a **development salt master and minion** see [examples/dev.sh](examples/dev.sh) 

After you exported your env vars, run install script for your environment. Will do:

- Update and upgrade Ubuntu apt packages
- Create project user with a pair of ssh keys 
- Install salt dependencies
- Bootstrap and configure SaltStack
- Install and configure fail2ban
- Configure `sshd` service to enhance security (allow only key auth)

```
bash install.sh
```

You'll be prompted at some point to add `project` user's public key to your Bitbucket and GitHub accounts. 

> Ignore this for minion prod envs, since they are fully controlled by salt masters to receive states and pillars.

Please add a Deployment Key for your salt repo. Git readonly access is enough for a prod master env.
However, if you are on a remote dev VPS machine, you want to add that key to your account, to gain write access as well.

## Salt keys

On the master VPS machine you'll have to accept salt minion keys (if not auto-accepted), in to make the connection with a newly added minion.

```
# List minion keys
salt-key -L

# Accept a minion key
salt-key -a minion1
```

## SSH - connect to your VPS

Keep your current ssh session, and attempt to connect again using the ssh config below.

On your machine, configure your `~/.ssh/config` so that you have something like:

```
KeepAlive yes
ServerAliveInterval 60

Host project-master
    Port 3269  # We avoid standard port 22.
    HostName 1.2.3.4  # VPS machine IP 
    User project  # VPS user to ssh with priv key
    IdentityFile ~/.ssh/project_master_id_rsa  # Local priv key, to match the pub key already available in VPS authorized keys.
```

On your machine, SSH into your VPS using your private key from `IdentityFile`:

```
ssh project-master
```

## VPS Provisioning

Run all SaltStack states for all minions:

```
sudo salt '*' state.apply
```

Also check out this useful salt cheatsheet.

https://github.com/harkx/saltstack-cheatsheet