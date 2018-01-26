define openldap::backupscript(
                              $destination,
                              $retention        = undef,
                              $logdir           = undef,
                              $mailto           = undef,
                              $idhost           = undef,
                              $backupscript     = '/usr/local/bin/backupopenldap',
                              $backupscriptconf = undef,
                              $hour             = '2',
                              $minute           = '0',
                            ) {

  validate_string($destination)

  #if ($openldap::mdb == "mdb")
  #{
  #	warn("http://www.openldap.org/faq/data/cache/287.html")
  #}

  if defined(Class['netbackupclient'])
  {
    netbackupclient::includedir{ $destination: }
  }

  exec { "mkdir_p_${destination}":
    command     => "/bin/mkdir -p ${destination}",
    refreshonly => true,
  }

  file { $destination:
    ensure  => 'directory',
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Exec["mkdir_p_${destination}"]
  }

  package { 'lmdb':
    ensure  => 'installed',
    require => Class['epel'],
  }

  file { $backupscript:
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Package['lmdb'],
    content => template("${module_name}/openldap_backup.erb")
  }

  cron { 'backupopenldap':
    command => $backupscript,
    user    => 'root',
    hour    => $hour,
    minute  => $minute,
  }

  if($backupscriptconf)
  {
    file { '$backupscriptconf':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Package['lmdb'],
      content => template("${module_name}/openldap_backup_conf.erb")
    }
  }
  else
  {
    file { '/usr/local/bin/backupopenldap.config':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      require => Package['lmdb'],
      content => template("${module_name}/openldap_backup_conf.erb")
    }
  }
}
