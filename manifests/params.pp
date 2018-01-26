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

  if ($openldap::updateref) and ($openldap::chainingoverlay)
  {
    fail("updateref (${openldap::updateref}) and chainingoverlay (${openldap::chainingoverlay}) are incompatible")
  }

  if($openldap::backend != 'mdb') and ($openldap::mdbsize)
  {
    fail("mdbsize incompatible with backend ${openldap::backend}")
  }

  if ($openldap::tlca) or ($openldap::tlscert) or ($openldap::tlspk)
  {
    if($openldap::tlca==undef) or ($openldap::tlscert==undef) or ($openldap::tlspk==undef)
    {
      fail("tls error, something is missing: CA: ${openldap::tlca} CERT: ${openldap::tlscert} PK: ${openldap::tlspk}")
    }
  }

  if($openldap::backend)
  {
    case $openldap::backend
    {
      'bdb': { }
      'mdb': { }
      default: { fail("${openldap::backend} is not supported") }
    }
  }
}
