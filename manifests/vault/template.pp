# @summary A short summary of the purpose of this defined type.
#
# A description of what this defined type does
#
# @example
#   hashiplat::vault::template { 'namevar': }
define hashiplat::vault::template (
  Optional[String]  $source               = undef,
  String            $destination          = $name,
  Optional[Boolean] $create_dest_dirs     = undef,
  Optional[String]  $contents             = undef,
  Optional[String]  $command              = undef,
  Optional[String]  $command_timeout      = undef,
  Optional[Boolean] $error_on_missing_key = undef,
  Optional[String]  $perms                = undef,
  Optional[String]  $backup               = undef,
  Optional[String]  $left_delimiter       = undef,
  Optional[String]  $right_delimiter      = undef,
  Optional[String]  $sandbox_path         = undef,
  Optional[String]  $wait                 = undef,
) {
  include hashiplat::vault::client

  $abs_dest = $destination[0] ? {
    '/'     => $destination,
    default => join([$hashiplat::vault::client::data_dir, $destination], '/'),
  }

  $no_slash_dest = join(split($destination, '[/]'), '_')

  file { "${hashiplat::vault::client::config_dir}/${no_slash_dest}.json":
    ensure  => file,
    owner   => $hashiplat::vault::user,
    group   => $hashiplat::vault::group,
    mode    => '0440',
    content => to_json({
      template => [({
        source               => $source,
        destination          => $abs_dest,
        create_dest_dirs     => $create_dest_dirs,
        contents             => $contents,
        command              => $command,
        command_timeout      => $command_timeout,
        error_on_missing_key => $error_on_missing_key,
        perms                => $perms,
        backup               => $backup,
        left_delimiter       => $left_delimiter,
        right_delimiter      => $right_delimiter,
        sandbox_path         => $sandbox_path,
        wait                 => $wait,
      }).filter |$k, $v| { $v != undef }],
    }),
  }
}
