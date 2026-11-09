# @summary Baseline config applied to every lab node.
#
# Values come from Hiera (data/common.yaml, overridable per node).
#
# @param motd_message
#   Line shown in /etc/motd.
# @param packages
#   Extra packages to install.
# @param ntp_servers
#   NTP pool servers written to /etc/chrony.conf.
# @param timezone
#   System timezone (e.g. Australia/Sydney).
class profile::base (
  String[1]        $motd_message,
  Array[String[1]] $packages,
  Array[String[1]] $ntp_servers,
  String[1]        $timezone,
) {
  # --- Packages ---
  package { $packages:
    ensure => installed,
  }

  # --- Time: chrony + timezone ---
  package { 'chrony':
    ensure => installed,
  }

  file { '/etc/chrony.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/chrony.conf.epp', { 'ntp_servers' => $ntp_servers }),
    require => Package['chrony'],
    notify  => Service['chronyd'],
  }

  service { 'chronyd':
    ensure => running,
    enable => true,
  }

  exec { 'set-timezone':
    command  => "timedatectl set-timezone ${timezone}",
    unless   => "test \"$(timedatectl show --property=Timezone --value)\" = '${timezone}'",
    path     => ['/usr/bin', '/usr/sbin', '/bin'],
    provider => shell,
  }

  # --- MOTD ---
  file { '/etc/motd':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('profile/motd.epp', {
        'message'     => $motd_message,
        'certname'    => $trusted['certname'],
        'environment' => $server_facts['environment'],
        'os'          => "${facts['os']['name']} ${facts['os']['release']['full']}",
    }),
  }

  # --- Marker file: easy proof that Puppet ran ---
  file { '/etc/puppet-managed':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "This host is managed by Puppet from the ${server_facts['environment']} environment.\n",
  }
}
