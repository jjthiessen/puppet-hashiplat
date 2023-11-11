# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include hashiplat::consul
class hashiplat::consul (
  Optional[String]  $version        = undef,
  Boolean           $manage_user    = true,
  String            $user           = 'consul',
  String            $group          = 'consul',
  String            $config_dir     = '/etc/consul',
  String            $data_dir       = '/var/lib/consul',
  String            $region         = $hashiplat::region,
  String            $puppet_ssl_dir = '/etc/puppetlabs/puppet/ssl',
  String            $tls_ca         = "${puppet_ssl_dir}/certs/ca.pem",
  String            $tls_cert       = "${puppet_ssl_dir}/certs/${trusted['certname']}.pem",
  String            $tls_key        = "${puppet_ssl_dir}/private_keys/${trusted['certname']}.pem",
  Hash[String, Any] $config         = {},
) inherits hashiplat {
  hashiplat::app { 'consul':
    version     => $version,
    manage_user => $manage_user,
    user        => $user,
    group       => $group,
    config_dir  => $config_dir,
    data_dir    => $data_dir,
  }
}
