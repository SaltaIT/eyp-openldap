define openldap::schema (
                          $ldif,
                          $schemaname = $name,
                          $replace    = true,
                        ){

  #TODO: habilitar el files/openssh-ldap.ldif

  file { "${openldap::slapdtmpbase}/schema.${schemaname}.ldif":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    replace => $replace,
    source  => $ldif,
    require => Package[$openldap::params::paquetsldap],
    notify  => Exec["bash addschema ${schemaname}"],
  }

  file { "${openldap::slapdtmpbase}/addschema.${schemaname}":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/addschema.erb"),
    notify  => Exec["bash addschema ${schemaname}"],
    audit   => 'content',
  }

  exec { "bash addschema ${schemaname}":
    command     => "/bin/bash ${openldap::slapdtmpbase}/addschema.${schemaname}",
    require     => File["${openldap::slapdtmpbase}/schema.${schemaname}.ldif"],
    refreshonly => true,
  }

}
