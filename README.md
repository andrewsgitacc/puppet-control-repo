# puppet-control-repo

**Author:** Andrew Kyle — [LinkedIn](https://www.linkedin.com/in/andrew-kyle-1007591/)

Puppet control repo for the OpenVox lab in [`labs/puppet`](https://github.com/andrewsgitacc/labs/tree/main/puppet). The Puppet server (`puppet.lab.local`) runs **r10k**, which polls this repo every 5 minutes and deploys it straight into the server's code directory.

> **Note:** This repo is public because it's a lab for learning. A real control repo would normally be private, and the Puppet server would read it with a read-only deploy key.

## How it works

```
 PR ──(CI: validate)──► main ──► Kargo Warehouse (new Freight = a main commit)
                                     │
        development (automatic) ──► staging (Promote) ──► production (Promote)
              │                          │                       │
     branch development          branch staging          branch production
              └──────── r10k on puppet.lab.local, every 5 min ────┘
                     /etc/puppetlabs/code/environments/<branch>
                                         │
       puppet, puppet-client-01/02 ◄── agents run production every 10 min
```

- **You change `main`, through pull requests.** CI (`.github/workflows/validate.yml`) must be
  green before a PR can merge.
- **[Kargo](https://kargo.apps.lab.local) owns the environment branches** `development`,
  `staging` and `production` (Phase 10b of the
  [platform lab](https://github.com/andrewsgitacc/labs/tree/main/platform)). Every new commit
  on `main` becomes **Freight**; Kargo copies it into `development` automatically, and into
  `staging`, then `production`, when you press **Promote** — each only with Freight the
  previous environment already has. Never push to those branches yourself.
- **Every branch except `main` becomes a Puppet environment** (r10k). All nodes run
  `production`; `development` and `staging` are there to try a change before it reaches the
  nodes (see *Preview a change* below). Rolling back = promoting older Freight.
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
.github/workflows/validate.yml   # CI: Puppetfile, YAML, parser/epp validate, puppet-lint
Gemfile                          # CI tools: openvox, puppet-lint, r10k
```

## What the starter code does

`profile::base` runs on every node and manages:

| Resource | Detail |
|---|---|
| Packages | `vim-enhanced`, `tree`, `bash-completion` (client-01 also gets `jq`) |
| `/etc/chrony.conf` + `chronyd` | AU NTP pool servers |
| Timezone | `Australia/Sydney` |
| `/etc/motd` | Message from Hiera plus host, OS and environment |
| `/etc/puppet-managed` | Marker file showing which environment last configured the host |

## Workflow

### Make a change

```bash
git checkout main && git pull
git checkout -b change-motd
# edit data/common.yaml, e.g. change profile::base::motd_message
git commit -am "Change MOTD" && git push -u origin change-motd
```

Open a pull request into `main`, wait for **validate** to go green, merge. Within ~2 minutes
Kargo has new Freight and promotes it to `development`; r10k deploys that branch within 5
minutes (to deploy now: `ssh -t admin@172.16.79.70 "sudo systemctl start r10k-deploy.service"`).

### Preview a change

All nodes use `production`, so a change in `development` or `staging` doesn't touch them
yet. See what it *would* do on a client, without changing anything:

```bash
ssh -t admin@172.16.79.71 "sudo /opt/puppetlabs/bin/puppet agent -t --noop --environment development"
```

### Promote

In the Kargo UI (project **puppet**): Freight → **Promote** to `staging`, then to
`production`. After r10k has deployed `production`, agents apply it on their next run (every
10 minutes), or now: `ssh -t admin@172.16.79.71 "sudo /opt/puppetlabs/bin/puppet agent -t"`.
`git log origin/production` shows every promotion.

### Test a feature branch

Pushing a branch still creates an environment of the same name (r10k), so you can try it
on one client before opening the PR:

```bash
ssh -t admin@172.16.79.71 "sudo /opt/puppetlabs/bin/puppet agent -t --noop --environment change_motd"
```

(Environment names allow only letters, digits and `_`, so r10k turns `change-motd` into
`change_motd`.)
When you delete the branch, r10k removes the environment.

### Add a Forge module

Add a `mod` line to the `Puppetfile`, then use the module's classes from a profile.

## CI

`.github/workflows/validate.yml` runs `r10k puppetfile check`, YAML parsing,
`puppet parser validate`, `puppet epp validate` and `puppet-lint` on GitHub-hosted runners,
for every pull request into `main`. A branch rule on `main` requires it (Settings → Rules).
(Before Phase 10b this ran as a Jenkins job on `production`; `labs/puppet` still has the
Jenkins playbook if you want it back.)
