class openldap::indexes($indexes) {

  validate_array($indexes)

  file { "${openldap::slapdtmpbase}/addindexes":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/addindexes.erb"),
    notify  => Exec['bash addindexes'],
    audit   => 'content',
  }

  exec { 'bash addindexes':
    command     => "/bin/bash ${openldap::slapdtmpbase}/addindexes",
    refreshonly => true,
  }
}
