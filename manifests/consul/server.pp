# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include hashiplat::consul::server
class hashiplat::consul::server (
  String            $config_dir = "${hashiplat::consul::config_dir}/server",
  String            $data_dir   = "${hashiplat::consul::data_dir}/server",
  String            $region     = $hashiplat::consul::region,
  String            $tls_ca     = $hashiplat::consul::tls_ca,
  String            $tls_cert   = $hashiplat::consul::tls_cert,
  String            $tls_key    = $hashiplat::consul::tls_key,
  Hash[String, Any] $config     = {},
) inherits hashiplat::consul {
  $consul_query = @("QUERY"/L)
    nodes [certname] { \
      resources { \
        type = "Class" \
        and title = "Hashiplat::Consul::Server" \
        and parameters.region = "${region}" \
      } \
    }
    |- QUERY

  $server_config = {
    server => true,

    ui_config => {
      enabled => true,
    },

    addresses => {
      https => '0.0.0.0',
    },

    ports => {
      http  => -1,
      https => 8501,
    },

    http_config => {
      # TODO: Restrict this later on?
      allow_write_http_from => [
        '0.0.0.0/0',
        #'127.0.0.0/8',
        #'10.0.0.0/8',
      ],
    },

    # REVIEW: Do we need this?
    #enable_local_script_checks => true

    acl => {
      default_policy           => 'deny',
      down_policy              => 'extend-cache',
      enabled                  => true,
      enable_token_persistence => true,
      tokens                   => {
        agent              => '91d47973-def0-47ac-9453-fc298b5cd731', # TODO: Don't use hardcoded example tokens
        initial_management => '91d47973-def0-47ac-9453-fc298b5cd731',
      },
    },

    data_dir => "${data_dir}/data",

    retry_join => (puppetdb_query($consul_query).map |$x| { $x['certname'] }).sort,

    # TODO: Un-hardcode
    encrypt => 'aPuGh+5UDskRAbkLaXRzFoSOcSM+5vAK+NEYOWHJH7w=',

    verify_incoming        => true,
    verify_outgoing        => true,
    verify_server_hostname => true,

    ca_file   => "${config_dir}/tls/ca.pem",
    cert_file => "${config_dir}/tls/public.pem",
    key_file  => "${config_dir}/tls/private.pem",
  }

  hashiplat::instance { 'consul-server':
    config     => deep_merge($hashiplat::consul::config, $server_config, $config).filter |$k, $v| { $v != undef },
    config_dir => $config_dir,
    data_dir   => $data_dir,
    user       => $hashiplat::consul::user,
    group      => $hashiplat::consul::group,
    tls_ca     => $tls_ca,
    tls_cert   => $tls_cert,
    tls_key    => $tls_key,
  }

  file { $config_dir:
    ensure => directory,
    owner  => $hashiplat::consul::user,
    group  => $hashiplat::consul::group,
    mode   => '0550',
  }

  file { $data_dir:
    ensure       => directory,
    owner        => $hashiplat::consul::user,
    group        => $hashiplat::consul::group,
    mode         => '0750',
    purge        => true,
    recurse      => true,
    force        => true,
    recurselimit => 1,
  }

  file { "${data_dir}/data":
    ensure  => directory,
    owner   => $hashiplat::consul::user,
    group   => $hashiplat::consul::group,
    mode    => '0750',
    require => File[$data_dir],
  }

  # REVIEW: Should this be exposed, or should we force the use of a local client agent or a real DNS server with a local client agent?
  firewall { '500 Allow Consul DNS connections':
    dport  => 8600,
    state  => 'NEW',
    action => 'accept',
    proto  => ['tcp', 'udp'],
  }

  firewall { '500 Allow Consul HTTPS API connections':
    dport  => 8501,
    state  => 'NEW',
    action => 'accept',
    proto  => 'tcp',
  }

  firewall { '500 Allow Consul LAN Serf connections':
    dport  => 8301,
    state  => 'NEW',
    action => 'accept',
    proto  => ['tcp', 'udp'],
  }

  firewall { '500 Allow Consul WAN Serf connections':
    dport  => 8302,
    state  => 'NEW',
    action => 'accept',
    proto  => ['tcp', 'udp'],
  }

  firewall { '500 Allow Consul Server RPC connections':
    dport  => 8300,
    state  => 'NEW',
    action => 'accept',
    proto  => 'tcp',
  }
}
