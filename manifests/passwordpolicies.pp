#TODO: transformar en define
class openldap::passwordpolicies(
                                  $backendindex = '2',
                                  $policiesdn   = "ou=policies,${openldap::base}",
                                ) {

  exec { 'cleartextpassword-passwordpolicies':
    command => "/bin/echo ${openldap::adminpassword} > ${openldap::slapdtmpbase}/.cleartextpass-passwordpolicies",
    creates => "${openldap::slapdtmpbase}/.cleartextpass-passwordpolicies",
    require => Exec['bash initdb'],
  }

  file { "${openldap::slapdtmpbase}/enablepasswordpolicies":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['cleartextpassword-passwordpolicies'],
    content => template("${module_name}/enablepasswordpolicies.erb"),
    #notify => Exec["bash enablepasswordpolicies"],
    #audit  => 'content',
  }

  exec { 'bash enablepasswordpolicies':
    command     => "/bin/bash ${openldap::slapdtmpbase}/enablepasswordpolicies >> ${openldap::slapdtmpbase}/.enablepasswordpolicies.log 2>&1",
    refreshonly => true,
  }

}
