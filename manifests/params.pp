class openldap::params {

  $ldapserver_pkg= [ 'openldap', 'openldap-servers' ]
  $ldapclient_pkg= [ 'openldap-clients' ]

  $slapdtmpbase='/etc/openldap/.slapdtmp'

  case $::osfamily
  {
    'redhat':
    {
      case $::operatingsystemrelease
      {
        /^6.*$/: { }
        /^7.*$/: { }
        default: { fail('Unsupported RHEL/CentOS version!')  }
      }
    }
    default: { fail('Unsupported OS!')  }
  }
}
