Puppet::Type.type(:openldap_config).provide(:openldap_config) do
  desc 'openldap_config'

  commands :ldapsearch => '/usr/bin/ldapsearch'

  if Puppet::Util::Package.versioncmp(Puppet.version, '3.0') >= 0
    has_command(:pip, '/usr/bin/ldapsearch') do
      is_optional
      environment :HOME => "/root"
    end
  end

  def self.instances
    ldapsearch(['-Y','EXTERNAL','-H','ldapi:///','-b','cn=config','-s','base']).scan(/^([a-zA-Z]+): (.*)$/).collect do |config|
      debug "setting "+config[0]+": "+config[1]
      new(
        :ensure => :present,
        :name => config[0]
        :value => config[1]
        )
    end
  end

  def self.prefetch(resources)
    resources.keys.each do |name|
      if provider = instances.find{ |setting| setting.name == name }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present || false
  end

end
# [root@centos7 ~]# ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=config  -s base 2>/dev/null
# # extended LDIF
# #
# # LDAPv3
# # base <cn=config> with scope baseObject
# # filter: (objectclass=*)
# # requesting: ALL
# #
#
# # config
# dn: cn=config
# objectClass: olcGlobal
# cn: config
# olcArgsFile: /var/run/openldap/slapd.args
# olcDisallows: bind_anon
# olcIdleTimeout: 1
# olcLogLevel: stats conns
# olcPidFile: /var/run/openldap/slapd.pid
# olcTLSCACertificatePath: /etc/openldap/certs
# olcTLSCertificateFile: "OpenLDAP Server"
# olcTLSCertificateKeyFile: /etc/openldap/certs/password
# olcWriteTimeout: 2
#
# # search result
# search: 2
# result: 0 Success
#
# # numResponses: 2
# # numEntries: 1
# [root@centos7 ~]#
