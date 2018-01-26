class openldap() inherits openldap::params {
  package { $openldap::params::ldapclient_pkg:
    ensure => 'installed',
  }
}
