# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   hashiplat::vault::certificate { 'namevar': }
define hashiplat::vault::certificate (
  String                               $pki_mount        = 'pki',
  String                               $pki_role         = split($::fqdn, '[.]')[1],
  Optional[String]                     $tls_dir          = undef,
  Optional[String]                     $tls_cert_pem     = undef,
  Optional[String]                     $tls_ca_pem       = undef,
  Optional[String]                     $tls_bundle_pem   = undef,
  Optional[String]                     $tls_chain_pem    = undef,
  Optional[String]                     $tls_key_pem      = undef,
  String                               $common_name      = $name,
  Optional[Array[String]]              $dns_sans         = undef,
  Array[Stdlib::IP::Address::Nosubnet] $ip_sans          = ['127.0.0.1'],
  Optional[Boolean]                    $create_dest_dirs = true,
  Optional[String]                     $command          = undef,
  Optional[String]                     $command_timeout  = undef,
  Optional[String]                     $wait             = undef,
  Optional[String]                     $unit             = undef, # TODO
) {
  # TODO: Systemd integration to encrypt and save?
  # TODO: Systemd integration to load un-encrypted secrets.
  #       Drop-in with LoadCredential=${name}:${tls_dir}

  $_tls_dir = $tls_dir ? {
    String => $tls_dir,
    Undef  => join([$hashiplat::vault::client::data_dir, 'tls', $common_name], '/'),
  }

  $_tls_cert_pem = $tls_cert_pem ? {
    String => $tls_cert_pem,
    Undef  => join([$_tls_dir, 'public.pem'], '/'),
  }

  $_tls_ca_pem = $tls_ca_pem ? {
    String => $tls_ca_pem,
    Undef  => join([$_tls_dir, 'ca.pem'], '/'),
  }

  $_tls_bundle_pem = $tls_bundle_pem ? {
    String => $tls_bundle_pem,
    Undef  => join([$_tls_dir, 'bundle.pem'], '/'),
  }

  $_tls_chain_pem = $tls_chain_pem ? {
    String => $tls_chain_pem,
    Undef  => join([$_tls_dir, 'chain.pem'], '/'),
  }

  $_tls_key_pem = $tls_key_pem ? {
    String => $tls_key_pem,
    Undef  => join([$_tls_dir, 'private.pem'], '/'),
  }

  $_dns_sans = $dns_sans ? {
    Array[String] => $dns_sans,
    Undef         => [$common_name, $::fqdn, "*.${::fqdn}", 'localhost'].sort.unique,
  }

  $with_secret_tmpl = @(TEMPLATE)
    with secret "<%= $issue_path %>" "common_name=<%= $common_name %>" <% unless ($dns_sans =~ Array[Any, 0, 0]) { -%> "alt_names=<%= $dns_sans.join(',') %>" <% } -%> <% unless ($ip_sans =~ Array[Any, 0, 0]) { -%> "ip_sans=<%= $ip_sans.join(',') %>" <% } -%>
    | - TEMPLATE

  $with_secret = inline_epp($with_secret_tmpl, {
    issue_path  => join([$pki_mount, 'issue', $pki_role], '/'),
    common_name => $common_name,
    dns_sans    => $_dns_sans,
    ip_sans     => $ip_sans,
  })

  $public_pem_tmpl_name  = "${name} - Public Certificate"
  #$public_pem_check_name = downcase(regsubst(regsubst("${public_pem_tmpl_name} Expiry Check", '[ ]+', '-', 'EG'), '-+', '-', 'EG'))

  hashiplat::vault::template { $public_pem_tmpl_name:
    destination          => $_tls_cert_pem,
    create_dest_dirs     => $create_dest_dirs,
    command              => $command,
    command_timeout      => $command_timeout,
    error_on_missing_key => true,
    perms                => '0644',
    wait                 => $wait,
    contents             => @("TEMPLATE")
      {{ $with_secret }}
      {{ .Data.certificate }}
      {{ end }}
      | TEMPLATE
  }

  $ca_pem_tmpl_name  = "${name} - Issuing CA Certificate"
  #$ca_pem_check_name = downcase(regsubst(regsubst("${ca_pem_tmpl_name} Expiry Check", '[ ]+', '-', 'EG'), '-+', '-', 'EG'))

  hashiplat::vault::template { $ca_pem_tmpl_name:
    destination          => $_tls_ca_pem,
    create_dest_dirs     => $create_dest_dirs,
    command              => $command,
    command_timeout      => $command_timeout,
    error_on_missing_key => true,
    perms                => '0644',
    wait                 => $wait,
    contents             => @("TEMPLATE")
      {{ $with_secret }}
      {{ with index .Data.ca_chain 0 }}
      {{ . }}
      {{ end }}
      {{ end }}
      | TEMPLATE
  }

  $bundle_pem_tmpl_name  = "${name} - CA Certificate Bundle"
  #$bundle_pem_check_name = downcase(regsubst(regsubst("${bundle_pem_tmpl_name} Expiry Check", '[ ]+', '-', 'EG'), '-+', '-', 'EG'))

  hashiplat::vault::template { $bundle_pem_tmpl_name:
    destination          => $_tls_bundle_pem,
    create_dest_dirs     => $create_dest_dirs,
    command              => $command,
    command_timeout      => $command_timeout,
    error_on_missing_key => true,
    perms                => '0644',
    wait                 => $wait,
    contents             => @("TEMPLATE")
      {{ $with_secret }}
      {{ range .Data.ca_chain }}
      {{ . }}
      {{ end }}
      {{ end }}
      | TEMPLATE
  }

  $chain_pem_tmpl_name  = "${name} - Full Certificate Chain"
  #$chain_pem_check_name = downcase(regsubst(regsubst("${chain_pem_tmpl_name} Expiry Check", '[ ]+', '-', 'EG'), '-+', '-', 'EG'))

  hashiplat::vault::template { $chain_pem_tmpl_name:
    destination          => $_tls_chain_pem,
    create_dest_dirs     => $create_dest_dirs,
    command              => $command,
    command_timeout      => $command_timeout,
    error_on_missing_key => true,
    perms                => '0644',
    wait                 => $wait,
    contents             => @("TEMPLATE")
      {{ $with_secret }}
      {{ .Data.certificate }}
      {{ range .Data.ca_chain }}
      {{ . }}
      {{ end }}
      {{ end }}
      | TEMPLATE
  }

  hashiplat::vault::template { "${name} - Private Key":
    destination          => $_tls_key_pem,
    create_dest_dirs     => $create_dest_dirs,
    command              => $command,
    command_timeout      => $command_timeout,
    error_on_missing_key => true,
    perms                => '0640',
    wait                 => $wait,
    contents             => @("TEMPLATE")
      {{ $with_secret }}
      {{ .Data.private_key }}
      {{ end }}
      | TEMPLATE
  }
}
