class hashiplat::vault::server (
  String            $config_dir = "${hashiplat::vault::config_dir}/server",
  String            $data_dir   = "${hashiplat::vault::data_dir}/server",
  String            $region     = $hashiplat::vault::region,
  String            $tls_ca     = $hashiplat::vault::tls_ca,
  String            $tls_cert   = $hashiplat::vault::tls_cert,
  String            $tls_key    = $hashiplat::vault::tls_key,
  Hash[String, Any] $config     = {},
) inherits hashiplat::vault {
  $vault_query = @("QUERY"/L)
    nodes [certname] { \
      resources { \
        type = "Class" \
        and title = "Hashiplat::Vault::Server" \
        and parameters.region = "${region}" \
      } \
    }
    |- QUERY

  $server_config = {
    # VAULT_CLUSTER_ADDR
    cluster_addr         => "https://${::fqdn}:8201",
    # VAULT_API_ADDR
    api_addr             => "https://${::fqdn}:8200",

    disable_mlock        => true,

    listener             => {
      tcp => {
        address            => '{{ GetPrivateIP }}:8200',
        tls_client_ca_file => "${config_dir}/tls/ca.pem",
        tls_cert_file      => "${config_dir}/tls/public.pem",
        tls_key_file       => "${config_dir}/tls/private.pem",
      },
    },

    #service_registration => {
    #  consul => {
    #    address => '127.0.0.1:8500',
    #  },
    #},

    storage              => {
      raft => {
        path       => "${data_dir}/data/",
        retry_join => (puppetdb_query($vault_query).map |$x| { $x['certname'] }).sort.map |$instance| {
          {
            # leader_tls_servername => 'server.lab.vault',
            leader_api_addr         => "https://${instance}:8200",
            leader_ca_cert_file     => "${config_dir}/tls/ca.pem",
            leader_client_cert_file => "${config_dir}/tls/public.pem",
            leader_client_key_file  => "${config_dir}/tls/private.pem",
          }
        },
      },
    },
  }

  hashiplat::instance { 'vault-server':
    config     => deep_merge($hashiplat::vault::config, $server_config, $config).filter |$k, $v| { $v != undef },
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

  firewall { '500 Allow Vault client connections':
    dport  => 8200,
    state  => 'NEW',
    action => 'accept',
    proto  => 'tcp',
  }

  firewall { '500 Allow Vault cluster connections':
    dport  => 8201,
    state  => 'NEW',
    action => 'accept',
    proto  => 'tcp',
  }
}
