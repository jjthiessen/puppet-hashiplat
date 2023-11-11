# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   hashiplat::instance { 'namevar': }
define hashiplat::instance (
  Enum['consul', 'vault']  $app  = $name.split('-')[0],
  Enum['server', 'client'] $mode = $name.split('-')[1],
  Hash[String, Any]        $config,
  String                   $user,
  String                   $group,
  String                   $tls_ca,
  String                   $tls_cert,
  String                   $tls_key,
  String                   $data_dir,
  String                   $config_dir,
) {
  # Systemd unit

  $service = "${app}-${mode}"

  file { "/usr/lib/systemd/system/${service}.service":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/${app}.service.erb"),
  }

  ~> service { $service:
    ensure => running,
  }

  # Configuration

  $etc_config   = "${config_dir}/config"
  $etc_tls      = "${config_dir}/tls"

  # Actual configuration

  file { "${config_dir}/.env":
    ensure  => file,
    owner   => $user,
    group   => $group,
    mode    => '0440',
    require => File[$config_dir],
  }

  file { $etc_config:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0550',
    require => File[$config_dir],
  }

  concat_file { "${app}_${mode}_config":
    tag     => "${app}_${mode}_config",
    path    => "${etc_config}/${app}.json",
    format  => 'json-pretty',
    owner   => $user,
    group   => $group,
    mode    => '0440',
    before  => Service[$service],
    notify  => Service[$service],
    require => File[$etc_config],
  }

  concat_fragment { "${app}_${mode}_config_main":
    tag     => "${app}_${mode}_config",
    target  => "${app}_${mode}_config",
    content => to_json($config),
    order   => 1,
  }

  # TLS

  file { $etc_tls:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0550',
    require => File[$config_dir],
  }

  file { "${etc_tls}/ca.pem":
    source  => $tls_ca,
    owner   => $user,
    group   => $group,
    mode    => '0444',
    require => File[$etc_tls],
  }

  file { "${etc_tls}/public.pem":
    source  => $tls_cert,
    owner   => $user,
    group   => $group,
    mode    => '0444',
    require => File[$etc_tls],
  }

  file { "${etc_tls}/private.pem":
    source  => $tls_key,
    owner   => $user,
    group   => $group,
    mode    => '0440',
    require => File[$etc_tls],
  }

  concat { "${etc_tls}/chain.pem":
    owner   => $user,
    group   => $group,
    mode    => '0444',
    require => [
      User[$user],
      Group[$group],
      File["${etc_tls}/public.pem"],
      File["${etc_tls}/ca.pem"],
    ],
    notify  => Service[$service],
  }

  concat::fragment { "${app}_${mode}_ssl_cert_fragment":
    target => "${etc_tls}/chain.pem",
    source => "${etc_tls}/public.pem",
    order  => '01',
  }

  concat::fragment { "${app}_${mode}_ssl_ca_fragment":
    target => "${etc_tls}/chain.pem",
    source => "${etc_tls}/ca.pem",
    order  => '02',
  }
}
