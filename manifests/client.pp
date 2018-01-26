class openldap::client($host, $base) inherits openldap::params {

  file { '/etc/openldap/ldap.conf':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template("${module_name}/client/ldap.erb"),
  }
}
