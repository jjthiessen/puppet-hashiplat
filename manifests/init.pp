# @summary A short summary of the purpose of this class
#
# A description of what this class does
#
# @example
#   include hashiplat
class hashiplat (
  String $region,
) {
  # REVIEW: Do these need to be extracted into a params class so that we can determine package name by distro?
  package {['curl', 'gpg', 'jq', 'unzip']:
    ensure => present,
  }
}
