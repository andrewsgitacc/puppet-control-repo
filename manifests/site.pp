# Node classification: every node gets exactly one role.

node 'puppet.lab.local' {
  include role::puppet_server
}

node /^puppet-client-\d+\.lab\.local$/ {
  include role::client
}

node default {
  include role::base
}
