class openldap::memberof(
                          $backendindex='2'
                        ) {

  file { "${openldap::slapdtmpbase}/enablememberof":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/enablememberof.erb"),
    notify  => Exec['bash enablememberof'],
    audit   => 'content',
  }

  exec { 'bash enablememberof':
    command     => "/bin/bash ${openldap::slapdtmpbase}/enablememberof > ${openldap::slapdtmpbase}/.enablememberof.log 2>&1",
    refreshonly => true,
  }
}
