require 'tempfile'

Puppet::Type.type(:openldap_config).provide(:openldap_config) do
  desc 'openldap_config'

  commands  :ldapsearch => '/usr/bin/ldapsearch',
            :ldapmodify => '/usr/bin/ldapmodify'

  if Puppet::Util::Package.versioncmp(Puppet.version, '3.0') >= 0
    has_command(:pip, '/usr/bin/ldapsearch') do
      is_optional
      environment :HOME => "/root"
    end
  end

  def self.instances
    debug "instances"
    ldapsearch(['-Y','EXTERNAL','-H','ldapi:///','-b','cn=config','-s','base']).scan(/^(olc[a-zA-Z]+): (.*)$/).collect do |config|
      debug "setting "+config[0]+": "+config[1]
      Puppet::Type::Openldap_config::ProviderOpenldap_config.new(
        :ensure => :present,
        :name => config[0],
        :value => config[1]
        )
    end
  end

  def self.prefetch(resources)
    debug "prefetch"
    resources.keys.each do |name|
      unless instances.nil?
        if provider = instances.find{ |db| db.name == name }
          resources[name].provider = provider
        end
      end
    end
  end

  def exists?
    debug "exists?"
    @property_hash[:ensure] == :present || false
  end

  def create
    debug "create"
    file = Tempfile.new('openldap_confgi', '/tmp')
    begin
      file << "dn: cn=config\n"
      file << "add: #{resource[:name]}\n"
      file << "#{resource[:name]}: #{resource[:value]}\n"
      file.close
      # file.path
      Puppet.debug(IO.read file.path)

      begin
        ldapmodify(['-Y','EXTERNAL','-H','ldapi:///','-f',file.path])
      rescue Exception => e
        raise Puppet::Error, "LDIF content:\n#{IO.read file.path}\nError message: #{e.message}"
      end
    ensure
      file.unlink
    end
    @property_hash[:value] = value
  end

  def value
    debug "value"
    @property_hash[:value]
  end

  # cat <<EOF | ldapmodify -Y EXTERNAL -H ldapi:///
  # dn: cn=config
  # changetype: modify
  # replace: olcIdleTimeout
  # olcIdleTimeout: <%= @idletimeout %>
  # EOF
  def value=(value)
    debug "set value"
    file = Tempfile.new('openldap_confgi', '/tmp')
    begin
      file << "dn: cn=config\n"
      file << "changetype: modify\n"
      file << "replace: #{name}\n"
      file << "#{name}: #{value}\n"
      file.close
      # file.path
      Puppet.debug(IO.read file.path)

      begin
        ldapmodify(['-Y','EXTERNAL','-H','ldapi:///','-f',file.path])
      rescue Exception => e
        raise Puppet::Error, "LDIF content:\n#{IO.read file.path}\nError message: #{e.message}"
      end
    ensure
      file.unlink
    end
    @property_hash[:value] = value
  end

  def destroy
    debug "destroy"
    file = Tempfile.new('openldap_confgi', '/tmp')
    begin
      file << "dn: cn=config\n"
      file << "delete: #{name}\n"
      file.close
      # file.path
      Puppet.debug(IO.read file.path)

      begin
        ldapmodify(['-Y','EXTERNAL','-H','ldapi:///','-f',file.path])
      rescue Exception => e
        raise Puppet::Error, "LDIF content:\n#{IO.read file.path}\nError message: #{e.message}"
      end
    ensure
      file.unlink
    end
    @property_hash.clear
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
