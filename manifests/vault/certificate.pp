# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   hashiplat::vault::certificate { 'namevar': }
define hashiplat::vault::certificate (
  String                               $pki_mount        = 'pki',
  String                               $pki_role         = split($::fqdn, '[.]')[1],
  String                               $tls_dir          = join([$hashiplat::vault::client::data_dir, 'tls', $common_name], '/'),
  String                               $tls_cert_pem     = join([$tls_dir, 'public.pem'], '/'),
  String                               $tls_ca_pem       = join([$tls_dir, 'ca.pem'], '/'),
  String                               $tls_bundle_pem   = join([$tls_dir, 'bundle.pem'], '/'),
  String                               $tls_chain_pem    = join([$tls_dir, 'chain.pem'], '/'),
  String                               $tls_key_pem      = join([$tls_dir, 'private.pem'], '/'),
  String                               $common_name      = $name,
  Array[String]                        $dns_sans         = [$common_name, $::fqdn, "*.${::fqdn}", 'localhost'].sort.unique,
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

  $with_secret_tmpl = @(TEMPLATE)
    with secret "<%= $issue_path %>" "common_name=<%= $common_name %>" <% unless ($dns_sans =~ Array[Any, 0, 0]) { -%> "alt_names=<%= $dns_sans.join(',') %>" <% } -%> <% unless ($ip_sans =~ Array[Any, 0, 0]) { -%> "ip_sans=<%= $ip_sans.join(',') %>" <% } -%>
    | - TEMPLATE

  $with_secret = inline_epp($with_secret_tmpl, {
    issue_path  => join([$pki_mount, 'issue', $pki_role], '/'),
    common_name => $common_name,
    dns_sans    => $dns_sans,
    ip_sans     => $ip_sans,
  })

  $public_pem_tmpl_name  = "${name} - Public Certificate"
  #$public_pem_check_name = downcase(regsubst(regsubst("${public_pem_tmpl_name} Expiry Check", '[ ]+', '-', 'EG'), '-+', '-', 'EG'))

  hashiplat::vault::template { $public_pem_tmpl_name:
    destination          => $tls_cert_pem,
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

  profile::vault_agent::template { $ca_pem_tmpl_name:
    destination          => $tls_ca_pem,
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

  profile::vault_agent::template { $bundle_pem_tmpl_name:
    destination          => $tls_bundle_pem,
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

  profile::vault_agent::template { $chain_pem_tmpl_name:
    destination          => $tls_chain_pem,
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

  profile::vault_agent::template { "${name} - Private Key":
    destination          => $tls_key_pem,
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
