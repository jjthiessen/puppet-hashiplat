# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   hashiplat::app { 'namevar': }
define hashiplat::app (
  Enum['consul', 'vault'] $app         = $name,
  Optional[String]        $version     = undef,
  Boolean                 $manage_user = true,
  String                  $user        = $app,
  String                  $group       = $app,
  String                  $config_dir  = "/etc/${app}",
  String                  $data_dir    = "/var/lib/${app}",
) {
  if $version =~ String {
    class { "hashicorp::${app}":
      version => $version,
    }
  }

  if $manage_user {
    user { $user:
      ensure     => present,
      system     => true,
      managehome => false,
      home       => '/var/empty',
      gid        => $group,
      shell      => '/bin/false',
      require    => Group[$group],
    }

    group { $group:
      ensure => present,
      system => true,
    }
  }

  file { $config_dir:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0750',
    purge   => true,
    recurse => true,
    force   => true,
  }

  file { $data_dir:
    ensure       => directory,
    owner        => $user,
    group        => $group,
    mode         => '0750',
    purge        => true,
    recurse      => true,
    force        => true,
    recurselimit => 1,
  }
}
