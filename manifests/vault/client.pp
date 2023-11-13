# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include hashiplat::vault::client
class hashiplat::vault::client (
  String            $config_dir = "${hashiplat::vault::config_dir}/client",
  String            $data_dir   = "${hashiplat::vault::data_dir}/client",
  Array[String]     $servers    = $hashiplat::vault::servers,
  String            $tls_ca     = $hashiplat::vault::tls_ca,
  String            $tls_cert   = $hashiplat::vault::tls_cert,
  String            $tls_key    = $hashiplat::vault::tls_key,
  Hash[String, Any] $config     = {},
) inherits hashiplat::vault {
  $client_config = {
    vault => {
      # REVIEW: Address has to be unitary:
      #         - if we use a single instance, we tie the availability of downstream services to that instance
      #         - if we use Consul DNS, Consul has to be online (but it, too, depends on Vault working), complicating bootstrapping
      address     => "https://${servers[0]}:8200", # TODO: Do something better here
      ca_cert     => "${config_dir}/tls/ca.pem",
      client_cert => "${config_dir}/tls/public.pem",
      client_key  => "${config_dir}/tls/private.pem",
    },

    auto_auth => {
      method => [{
        type => 'cert',
        config => {
          reload => true,
        },
      }],
    },

    cache => {},

    #api_proxy => {
    #  use_auto_auth_token => true,
    #},

    #listener => {
    #  unix => {
    #    address     => "${data_dir}/vault.sock",
    #    tls_disable => true,
    #  },
    #},

    #service_registration => {
    #  consul => {
    #    address => '127.0.0.1:8500',
    #  },
    #},
  }

  hashiplat::instance { 'vault-client':
    config     => deep_merge($hashiplat::vault::config, $client_config, $config).filter |$k, $v| { $v != undef },
    config_dir => $config_dir,
    data_dir   => $data_dir,
    user       => $hashiplat::vault::user,
    group      => $hashiplat::vault::group,
    tls_ca     => $tls_ca,
    tls_cert   => $tls_cert,
    tls_key    => $tls_key,
  }

  file { $config_dir:
    ensure => directory,
    owner  => $hashiplat::vault::user,
    group  => $hashiplat::vault::group,
    mode   => '0750',
  }

  file { $data_dir:
    ensure       => directory,
    owner        => $hashiplat::vault::user,
    group        => $hashiplat::vault::group,
    mode         => '0750',
    purge        => true,
    recurse      => true,
    force        => true,
    recurselimit => 1,
  }

  file { "${data_dir}/data":
    ensure  => directory,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0750',
    require => File[$data_dir],
  }

  # TODO: Remove me - this is just for testing
  hashiplat::vault::certificate { 'foo':
  }
}
