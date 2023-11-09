# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include hashiplat::vault
class hashiplat::vault (
  Optional[String]  $version        = undef,
  Boolean           $manage_user    = true,
  String            $user           = 'vault',
  String            $group          = 'vault',
  String            $config_dir     = '/etc/vault',
  String            $data_dir       = '/var/lib/vault',
  String            $region         = $hashiplat::region,
  String            $puppet_ssl_dir = '/etc/puppetlabs/puppet/ssl',
  String            $tls_ca         = "${puppet_ssl_dir}/certs/ca.pem",
  String            $tls_cert       = "${puppet_ssl_dir}/certs/${trusted['certname']}.pem",
  String            $tls_key        = "${puppet_ssl_dir}/private_keys/${trusted['certname']}.pem",
  Hash[String, Any] $config         = {},
) inherits hashiplat {
  if $version =~ String {
    class { 'hashicorp::vault':
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
