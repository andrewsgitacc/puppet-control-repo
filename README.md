# puppet-control-repo

**Author:** Andrew Kyle — [LinkedIn](https://www.linkedin.com/in/andrew-kyle-1007591/)

Puppet control repo for the OpenVox lab in [`labs/puppet`](https://github.com/andrewsgitacc/labs/tree/main/puppet). The Puppet server (`puppet.lab.local`) runs **r10k**, which polls this repo every 5 minutes and deploys it straight into the server's code directory.

> **Note:** This repo is public because it's a lab for learning. A real control repo would normally be private, and the Puppet server would read it with a read-only deploy key.

## How it works

```
 git push ──► GitHub ──(r10k polls every 5 min)──► puppet.lab.local
                                                   /etc/puppetlabs/code/environments/<branch>
                                                          │
                       puppet-client-01/02 ◄──(agent runs every 10 min)
```

- **Every Git branch becomes a Puppet environment.** The default branch is `production`, which is the environment agents use by default. A branch called `feature_motd` becomes the `feature_motd` environment.
- The **Puppetfile** lists Forge or Git modules. r10k installs them into `modules/`, which is not committed.
- **Hiera** (`data/`) holds the settings. `common.yaml` applies to every node, and `nodes/<certname>.yaml` overrides it for one node.
- **Roles and profiles:** `site.pp` gives each node one **role**. Each role includes **profiles**, and each profile does the actual configuration.

## Layout

```
Puppetfile                       # Forge/Git module list (r10k)
environment.conf                 # modulepath = site-modules:modules
hiera.yaml                       # Hiera v5 hierarchy
data/
  common.yaml                    # defaults for every node
  nodes/puppet-client-01.lab.local.yaml   # per-node override example
manifests/site.pp                # node -> role mapping
site-modules/
  role/manifests/                # role::client, role::puppet_server, role::base
  profile/manifests/base.pp      # packages, chrony, timezone, MOTD, marker file
  profile/templates/             # EPP templates
Jenkinsfile                      # CI: Puppetfile, YAML, parser validate, puppet-lint
```

## What the starter code does

`profile::base` runs on every node and manages:

| Resource | Detail |
|---|---|
| Packages | `vim-enhanced`, `tree`, `htop` (client-01 also gets `jq`) |
| `/etc/chrony.conf` + `chronyd` | AU NTP pool servers |
| Timezone | `Australia/Sydney` |
| `/etc/motd` | Message from Hiera plus host, OS and environment |
| `/etc/puppet-managed` | Marker file showing which environment last configured the host |

## Workflow

### Make a change

```bash
git clone git@github.com:andrewsgitacc/puppet-control-repo.git
cd puppet-control-repo
# edit data/common.yaml, e.g. change profile::base::motd_message
git commit -am "Change MOTD" && git push
```

Within about 5 minutes r10k deploys the change. Agents pick it up on their next run, which happens every 10 minutes. To apply it immediately:

```bash
# Optional: force r10k to deploy now instead of waiting for the timer
ssh -t admin@172.16.79.70 "sudo systemctl start r10k-deploy.service"

# Run the agent on a client
ssh -t admin@172.16.79.71 "sudo /opt/puppetlabs/bin/puppet agent -t"
```

### Test on a branch first

```bash
git checkout -b feature_motd
# edit ...
git push -u origin feature_motd
# after r10k deploys it, try it on one client only:
ssh -t admin@172.16.79.71 "sudo /opt/puppetlabs/bin/puppet agent -t --environment feature_motd"
```

When you're happy with it, merge into `production`. When you delete the branch, r10k removes the environment.

### Add a Forge module

Add a `mod` line to the `Puppetfile`, then use the module's classes from a profile.

## CI (Jenkins)

The `Jenkinsfile` runs `r10k puppetfile check`, YAML parsing, `puppet parser validate`, `puppet epp validate` and `puppet-lint`. Set up the job like the other labs:

- **Pipeline script from SCM**
- Repository URL: `https://github.com/andrewsgitacc/puppet-control-repo.git`
- Branch: `*/production`
- Script Path: `Jenkinsfile`

First install the Puppet tooling on the Jenkins VM with `labs/puppet/04_configure_jenkins_for_puppet.yml`.

> CI only reports problems. r10k deploys whatever is pushed to a branch, so use a feature branch, wait for a green build, then merge.
