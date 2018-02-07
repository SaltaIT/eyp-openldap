class openldap::client(
                        $host = undef,
                        $base = undef,
                      ) inherits openldap::params {

  package { $openldap::params::ldapclient_pkg:
    ensure => 'installed',
  }

  file { '/etc/openldap/ldap.conf':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/client/ldap.erb"),
    require => Package[$openldap::params::ldapclient_pkg],
  }
}
