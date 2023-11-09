# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   hashiplat::vault::instance { 'namevar': }
define hashiplat::vault::instance (
  Enum['server', 'agent'] $mode = $name,
  Hash[String, Any]       $config,
  String                  $tls_ca,
  String                  $tls_cert,
  String                  $tls_key,
  String                  $data_dir,
  String                  $config_dir,
) {
  # Systemd unit

  $service = "vault-${mode}"

  file { "/usr/lib/systemd/system/${service}.service":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/vault.service.erb"),
  }

  ~> service { $service:
    ensure => running,
  }

  # Configuration

  $etc_config   = "${config_dir}/config"
  $etc_tls      = "${config_dir}/tls"

  # Actual configuration

  file { $etc_config:
    ensure  => directory,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0750',
    require => File[$config_dir],
  }

  $json_config = to_json(config)
  concat_file { "vault_${mode}_config":
    tag     => "vault_${mode}_config",
    path    => "${etc_config}/vault.json",
    format  => 'json-pretty',
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0640',
    before  => Service[$service],
    notify  => Service[$service],
    require => File[$etc_config],
  }

  # TLS

  file { $etc_tls:
    ensure  => directory,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0750',
    require => File[$config_dir],
  }

  file { "${etc_tls}/ca.pem":
    source  => $tls_ca,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0444',
    require => File[$etc_tls],
  }

  file { "${etc_tls}/public.pem":
    source  => $tls_cert,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0444',
    require => File[$etc_tls],
  }

  file { "${etc_tls}/private.pem":
    source  => $tls_key,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0440',
    require => File[$etc_tls],
  }

  concat { "${etc_tls}/chain.pem":
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0444',
    require => [
      User[$hashiplat::vault::user],
      Group[$hashiplat::vault::group],
      File["${etc_tls}/public.pem"],
      File["${etc_tls}/ca.pem"],
    ],
    notify  => Service[$service],
  }

  concat::fragment { "vault_${mode}_ssl_cert_fragment":
    target => "${etc_tls}/chain.pem",
    source => "${etc_tls}/public.pem",
    order  => '01',
  }

  concat::fragment { "vault_${mode}_ssl_ca_fragment":
    target => "${etc_tls}/chain.pem",
    source => "${etc_tls}/ca.pem",
    order  => '02',
  }
}
