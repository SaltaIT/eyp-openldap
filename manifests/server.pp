class openldap::server(
                        $base,
                        $admin,
                        $adminpassword,
                        $oname,
                        $slapdtmpbase          = $openldap::params::slapdtmpbase,
                        $is_master             = false,
                        $masterinfo            = undef,
                        $mm                    = undef,
                        $serverid              = '1',
                        $backend               = 'bdb',
                        $updateref             = undef,
                        $chainingoverlay       = undef,
                        $customschema          = undef,
                        $custominitdb          = undef,
                        $mdbsize               = '9126805504',
                        $tlsca                 = undef,
                        $tlscert               = undef,
                        $tlspk                 = undef,
                        $tlsstrongciphers      = true,
                        $tls_protocol_min      = undef,
                        $tls_cipher_suite      = undef,
                        $debuglevel            = '0',
                        $checkmdbusage         = '/usr/local/bin/check_mdb_usage',
                        $idletimeout           = '300',
                        $writetimeout          = '300',
                        $anonbind              = false,
                        $manage_service        = true,
                        $manage_docker_service = true,
                        $service_ensure        = 'running',
                        $service_enable        = true,
                      ) {

  #Openldap::Schema <| |> -> Openldap::Indexes <| |>

  validate_string($backend)
  validate_string($oname)
  validate_string($adminpassword)
  validate_string($slapdtmpbase)
  validate_string($base)
  validate_string($admin)
  validate_string($debuglevel)

  if ($updateref!=undef) { validate_string($updateref) }
  if ($chainingoverlay!=undef) { validate_string($chainingoverlay) }
  if ($customschema!=undef) { validate_string($customschema) }
  #if ($mdbsize) { validate_integer($mdbsize) }
  if ($checkmdbusage!=undef) { validate_absolute_path($checkmdbusage) }
  if ($masterinfo!=undef) { validate_array($masterinfo) }


  if ($openldap::server::updateref) and ($openldap::server::chainingoverlay)
  {
    fail("updateref (${openldap::server::updateref}) and chainingoverlay (${openldap::server::chainingoverlay}) are incompatible")
  }

  if($openldap::server::backend != 'mdb') and ($openldap::server::mdbsize)
  {
    fail("mdbsize incompatible with backend ${openldap::server::backend}")
  }

  if ($openldap::server::tlca) or ($openldap::server::tlscert) or ($openldap::server::tlspk)
  {
    if($openldap::server::tlca==undef) or ($openldap::server::tlscert==undef) or ($openldap::server::tlspk==undef)
    {
      fail("tls error, something is missing: CA: ${openldap::server::tlca} CERT: ${openldap::server::tlscert} PK: ${openldap::server::tlspk}")
    }
  }

  if($openldap::server::backend)
  {
    case $openldap::server::backend
    {
      'bdb': { }
      'mdb': { }
      default: { fail("${openldap::server::backend} is not supported") }
    }
  }

  if ($mm!=undef)
  {
    validate_array($mm)
  }

  include ::openldap
  include ::openldap::client

  package { $openldap::params::ldapserver_pkg:
    ensure  => 'installed',
  }

  if($checkmdbusage!=undef)
  {
    file { $checkmdbusage:
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => file("${module_name}/check_mdb_usage.sh")
    }
  }

  if ($backend == 'bdb')
  {
    file { '/var/lib/ldap/DB_CONFIG':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Package[$openldap::params::ldapserver_pkg],
      notify  => Class['::openldap::server::service'],
      content => template("${module_name}/dbconfig.erb")
    }
  }

  if ($tlsca) and ($tlscert) and ($tlspk)
  {
    package { 'openssl':
      ensure  => 'installed',
      require => Exec['bash initdb'],
    }

    file { '/etc/pki/tls/private/openldap-slapd.pk':
      ensure  => 'present',
      owner   => 'ldap',
      group   => 'root',
      mode    => '0400',
      require => Package['openssl'],
      replace => false,
      source  => $tlspk,
      notify  => Exec['bash enabletls'],
    }

    file { '/etc/pki/tls/certs/openldap-slapd-ca.crt':
      ensure  => 'present',
      owner   => 'ldap',
      group   => 'root',
      mode    => '0400',
      require => Package['openssl'],
      replace => false,
      source  => $tlsca,
      notify  => Exec['bash enabletls'],
    }

    file { '/etc/pki/tls/certs/openldap-slapd-cert.crt':
      ensure  => 'present',
      owner   => 'ldap',
      group   => 'root',
      mode    => '0400',
      require => Package['openssl'],
      replace => false,
      source  => $tlscert,
      notify  => Exec['bash enabletls'],
    }
  }

  #sysconfig

  file { '/etc/sysconfig/ldap':
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Class['::openldap::server::service'],
    content => template("${module_name}/sysconfigldap.erb"),
    require => Package[$openldap::params::ldapserver_pkg],
  }

  include ::openldap::server::service

  file { $slapdtmpbase:
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Class['::openldap::server::service']
  }

  if ($customschema)
  {
    file { "${slapdtmpbase}/init.schema":
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      require => File[$slapdtmpbase],
      replace => false,
      source  => $customschema
    }

    exec { 'init_schema':
      command => "/usr/bin/ldapadd -Y EXTERNAL -H ldapi:/// -f ${slapdtmpbase}/init.schema >> ${slapdtmpbase}/.init_schema.log 2>&1",
      require => [File["${slapdtmpbase}/init.schema"], Package[$openldap::params::ldapclient_pkg]],
      creates => "${slapdtmpbase}/.init_schema.log"
    }

    if($custominitdb)
    {
      file { "${slapdtmpbase}/custominitdb":
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0640',
        require => File[$slapdtmpbase],
        replace => false,
        source  => $custominitdb,
        notify  => Exec['bash initdb'],
      }
    }
  }

  file { "${slapdtmpbase}/initdb":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => File[$slapdtmpbase],
    content => template("${module_name}/initdb.erb")
  }

  exec { 'sshapassword':
    command => "/usr/sbin/slappasswd -s ${adminpassword} -h '{SSHA}' > ${slapdtmpbase}/.sshapass",
    creates => "${slapdtmpbase}/.sshapass",
    require => File["${slapdtmpbase}/initdb"]
  }

  exec { 'cleartextpassword':
    command => "/bin/echo ${adminpassword} > ${slapdtmpbase}/.cleartextpass",
    creates => "${slapdtmpbase}/.cleartextpass",
    require => Exec['sshapassword'],
  }

  exec { 'bash initdb':
    command => "/bin/bash ${slapdtmpbase}/initdb >> ${slapdtmpbase}/.sshapass.cleared 2>&1",
    require => [Exec['cleartextpassword'], Package[$openldap::params::ldapclient_pkg]],
    creates => "${slapdtmpbase}/.sshapass.cleared",
  }

  file { "${slapdtmpbase}/initreplicacio":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/initreplicacio.erb"),
    audit   => 'content',
  }

  exec { 'bash initreplicacio':
    command   => "/bin/bash ${slapdtmpbase}/initreplicacio >> ${slapdtmpbase}/.replicacio.ok 2>&1",
    subscribe => File["${slapdtmpbase}/initreplicacio"],
    creates   => "${slapdtmpbase}/.replicacio.ok",
  }


  file { "${slapdtmpbase}/initmaster":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initreplicacio'],
    content => template("${module_name}/initmaster.erb")
  }

  exec { 'bash initmaster':
    command   => "/bin/bash ${slapdtmpbase}/initmaster >> ${slapdtmpbase}/.master.ok 2>&1",
    subscribe => File["${slapdtmpbase}/initmaster"],
    creates   => "${slapdtmpbase}/.master.ok",
  }

  file { "${slapdtmpbase}/initslave":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initmaster'],
    content => template("${module_name}/initslave.erb")
  }

  exec { 'bash initslave':
    command   => "/bin/bash ${slapdtmpbase}/initslave >> ${slapdtmpbase}/.slave.ok 2>&1",
    subscribe => File["${slapdtmpbase}/initslave"],
    creates   => "${slapdtmpbase}/.slave.ok",
  }

  file { "${slapdtmpbase}/initmm":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initslave'],
    content => template("${module_name}/initmm.erb"),
  }

  exec { 'bash initmm':
    command   => "/bin/bash ${slapdtmpbase}/initmm >> ${slapdtmpbase}/.mm.ok 2>&1",
    subscribe => File["${slapdtmpbase}/initmm"],
    creates   => "${slapdtmpbase}/.mm.ok",
  }

  #
  # MDB size
  #

  file { "${slapdtmpbase}/mdbsize":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    notify  => Exec['bash mdbsize'],
    audit   => 'content',
    content => template("${module_name}/mdbsize.erb"),
  }

  exec { 'bash mdbsize':
    command     => "/bin/bash ${slapdtmpbase}/mdbsize",
    refreshonly => true,
  }

  #
  # enable TLS
  #

  if($tlspk!=undef)
  {
    # replace: olcTLSCACertificateFile
    # olcTLSCACertificateFile: /etc/pki/tls/certs/openldap-slapd-ca.crt
    openldap_config { 'olcTLSCACertificateFile':
      ensure => 'present',
      value  => '/etc/pki/tls/certs/openldap-slapd-ca.crt',
    }
    # replace: olcTLSCertificateFile
    # olcTLSCertificateFile: /etc/pki/tls/certs/openldap-slapd-cert.crt
    openldap_config { 'olcTLSCertificateFile':
      ensure => 'present',
      value  => '/etc/pki/tls/certs/openldap-slapd-cert.crt',
    }
    # replace: olcTLSCertificateKeyFile
    # olcTLSCertificateKeyFile: /etc/pki/tls/private/openldap-slapd.pk
    openldap_config { 'olcTLSCertificateKeyFile':
      ensure => 'present',
      value  => '/etc/pki/tls/private/openldap-slapd.pk',
    }

    if($tlsstrongciphers)
    {
      # replace: olcTLSProtocolMin
      # olcTLSProtocolMin: 3.1
      # replace: olcTLSCipherSuite
      # olcTLSCipherSuite: HIGH:!RC4:!MD5:!3DES:!DES:!aNULL:!eNULL
      openldap_config { 'olcTLSProtocolMin':
        ensure => 'present',
        value  => '3.1',
      }

      openldap_config { 'olcTLSCipherSuite':
        ensure => 'present',
        value  => 'HIGH:!RC4:!MD5:!3DES:!DES:!aNULL:!eNULL',
      }
    }
    else
    {
      if($tls_protocol_min!=undef)
      {
        openldap_config { 'olcTLSProtocolMin':
          ensure => 'present',
          value  => $tls_protocol_min,
        }
      }
      else
      {
        openldap_config { 'olcTLSProtocolMin':
          ensure => 'absent',
        }
      }

      if($tls_cipher_suite!=undef)
      {
        openldap_config { 'olcTLSCipherSuite':
          ensure => 'present',
          value  => $tls_cipher_suite,
        }
      }
      else
      {
        openldap_config { 'olcTLSCipherSuite':
          ensure => 'absent',
        }
      }
    }
  }
  else
  {
    openldap_config { 'olcTLSCACertificateFile':
      ensure => 'absent',
    }
    openldap_config { 'olcTLSCertificateFile':
      ensure => 'absent',
    }
    openldap_config { 'olcTLSCertificateKeyFile':
      ensure => 'absent',
    }
    openldap_config { 'olcTLSProtocolMin':
      ensure => 'absent',
    }
    openldap_config { 'olcTLSCipherSuite':
      ensure => 'absent',
    }
  }

  #
  # log level
  # replace: olcLogLevel
  # olcLogLevel: <%= @debuglevel %>
  openldap_config { 'olcLogLevel':
    ensure => 'present',
    value  => $debuglevel,
  }


  #
  # timeouts
  #
  # replace: olcIdleTimeout
  # olcIdleTimeout: <%= @idletimeout %>
  # idletimeout
  #
  # replace: olcWriteTimeout
  # olcWriteTimeout: <%= @writetimeout %>
  # writetimeout

  openldap_config { 'olcIdleTimeout':
    ensure => 'present',
    value  => $idletimeout,
  }

  openldap_config { 'olcWriteTimeout':
    ensure => 'present',
    value  => $writetimeout,
  }

  #
  # anon bind
  # add: olcDisallows
  # olcDisallows: bind_anon

  if($anonbind)
  {
    openldap_config { 'olcDisallows':
      ensure => 'absent',
    }
  }
  else
  {
    openldap_config { 'olcDisallows':
      ensure => 'present',
      value  => 'bind_anon',
    }
  }

  #
  # server ID
  # replace: olcServerID
  # olcServerID: <%= @serverid %>
  openldap_config { 'olcServerID':
    ensure => 'present',
    value  => $serverid,
  }
}
