class openldap::server(
                        $base,
                        $admin,
                        $adminpassword,
                        $oname,
                        $slapdtmpbase     = $openldap::params::slapdtmpbase,
                        $is_master        = false,
                        $masterinfo       = undef,
                        $mm               = undef,
                        $serverid         = '1',
                        $backend          = 'bdb',
                        $updateref        = undef,
                        $chainingoverlay  = undef,
                        $customschema     = undef,
                        $custominitdb     = undef,
                        $mdbsize          = '9126805504',
                        $tlsca            = undef,
                        $tlscert          = undef,
                        $tlspk            = undef,
                        $tlsstrongciphers = true,
                        $debuglevel       = '0',
                        $checkmdbusage    = '/usr/local/bin/check_mdb_usage',
                        $idletimeout      = '300',
                        $writetimeout     = '300',
                        $anonbind         = false,
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


  #WTF? marranda per validar al params, shauria de refer
  if(!defined(Class['openldap::params']))
  {
    class { 'openldap::params': }
  }

  package { $openldap::params::ldapserver_pkg:
    ensure  => 'installed',
    require => Class['openldap::params'], #ugly hack
  }

  if($checkmdbusage)
  {
    file { $checkmdbusage:
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template("${module_name}/check_mdb_usage.erb")
    }
  }

  if ($mm!=undef)
  {
    validate_array($mm)
    #validate_integer($serverid)
  }

  if ($backend == 'bdb')
  {
    file { '/var/lib/ldap/DB_CONFIG':
      ensure  => 'present',
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Package[$openldap::params::ldapserver_pkg],
      notify  => Service['slapd'],
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
    notify  => Service['slapd'],
    content => template("${module_name}/sysconfigldap.erb"),
    require => Package[$openldap::params::ldapserver_pkg],
  }


  service { 'slapd':
    ensure  => 'running',
    enable  => true,
    require => File['/etc/sysconfig/ldap'],
  }

  file { $slapdtmpbase:
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Service['slapd']
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

  file { "${slapdtmpbase}/enabletls":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    notify  => Exec['bash enabletls'],
    audit   => 'content',
    content => template("${module_name}/enabletls.erb"),
  }

  exec { 'bash enabletls':
    command     => "/bin/bash ${slapdtmpbase}/enabletls",
    refreshonly => true,
  }

  #
  # log level
  #

  file { "${slapdtmpbase}/loglevel":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/loglevel.erb"),
    notify  => Exec['bash loglevel'],
    audit   => 'content',
  }

  exec { 'bash loglevel':
    command     => "/bin/bash ${slapdtmpbase}/loglevel",
    refreshonly => true,
  }

  #
  # idle timeout
  #

  file { "${slapdtmpbase}/idletimeouts":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/idletimeouts.erb"),
    notify  => Exec['bash idletimeouts'],
    audit   => 'content',
  }

  exec { 'bash idletimeouts':
    command     => "/bin/bash ${slapdtmpbase}/idletimeouts",
    refreshonly => true,
  }

  #
  # anon bind
  #

  file { "${slapdtmpbase}/anonbind":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/anonbind.erb"),
    notify  => Exec['bash anonbind'],
    audit   => 'content',
  }

  exec { 'bash anonbind':
    command     => "/bin/bash ${slapdtmpbase}/anonbind",
    refreshonly => true,
  }

  #
  # server ID
  #

  file { "${slapdtmpbase}/serverid":
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    require => Exec['bash initdb'],
    content => template("${module_name}/serverid.erb"),
    notify  => Exec['bash serverid'],
    audit   => 'content',
  }

  #tarda bastant -_-
  exec { 'bash serverid':
    command     => "/bin/bash ${slapdtmpbase}/serverid",
    refreshonly => true,
    timeout     => 0,
  }


}
