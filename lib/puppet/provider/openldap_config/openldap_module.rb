require 'tempfile'

Puppet::Type.type(:openldap_module).provide(:openldap_module) do
  desc 'openldap_module'

  commands  :ldapsearch => '/usr/bin/ldapsearch',
            :ldapmodify => '/usr/bin/ldapmodify',
            :slapcat    => '/usr/sbin/slapcat'

  if Puppet::Util::Package.versioncmp(Puppet.version, '3.0') >= 0
    has_command(:pip, '/usr/bin/ldapsearch') do
      is_optional
      environment :HOME => "/root"
    end
  end

  # def init_module_list
  #   debug "init_module_list"
  #   file = Tempfile.new('openldap_module_init', '/tmp')
  #   begin
  #     file << "dn: cn=module{0},cn=config\n"
  #     file << "changetype: add\n"
  #     file << "cn: module\n"
  #     file << "objectclass: olcModuleList\n"
  #     file.close
  #     # file.path
  #     Puppet.debug(IO.read file.path)
  #
  #     begin
  #       ldapmodify(['-Y','EXTERNAL','-H','ldapi:///','-f',file.path])
  #     rescue Exception => e
  #       raise Puppet::Error, "LDIF content:\n#{IO.read file.path}\nError message: #{e.message}"
  #     end
  #   ensure
  #     file.unlink
  #   end
  # end

  def self.instances
    # slapcat -n 0 | grep module -i

    i = []

    nommodule = ''
    modulepath = ''
    slapcat(['-n','0']).scan(/.*odule.*/).collect do |line|
      debug line
      # [root@centos7 ~]# slapcat -n 0 | grep odule
      # dn: cn=module{0},cn=config
      # objectClass: olcModuleList
      # cn: module{0}
      # olcModuleLoad: {0}memberof
      # structuralObjectClass: olcModuleList
      # dn: cn=module{1},cn=config
      # objectClass: olcModuleList
      # cn: module{1}
      # olcModulePath: /usr/lib64/openldap
      # olcModuleLoad: {0}ppolicy
      # structuralObjectClass: olcModuleList
      # [root@centos7 ~]#

      # Debug: Puppet::Type::Openldap_module::ProviderOpenldap_module: dn: cn=module{0},cn=config
      # Debug: Puppet::Type::Openldap_module::ProviderOpenldap_module: objectClass: olcModuleList
      # Debug: Puppet::Type::Openldap_module::ProviderOpenldap_module: cn: module{0}
      # Debug: Puppet::Type::Openldap_module::ProviderOpenldap_module: olcModuleLoad: {0}memberof
      # Debug: Puppet::Type::Openldap_module::ProviderOpenldap_module: structuralObjectClass: olcModuleList
      case line
      # dn: cn=module{1},cn=config
      when /^dn:/
        debug "XX - nou dn: "+line
        # reset
        nommodule = ''
        modulepath = ''
      # olcModulePath: /usr/lib64/openldap
      when /^olcModulePath/
        if /^olcModulePath: (?<match>[^\.]+).*$/ =~ line
          modulepath = match
          debug "XX - match: "+modulepath
          debug "XX - olcModulePath: "+line
        end
      # olcModuleLoad: {0}ppolicy
      when /^olcModuleLoad/
        if /^olcModuleLoad: \{\d+\}(?<match>[^\.]+).*$/ =~ line
          nommodule = match
          debug "XX - match: "+nommodule
          debug "XX - olcModuleLoad: "+line
        end
      # structuralObjectClass: olcModuleList
      when /^structuralObjectClass: /
        debug "NEW MODULE INSTANCE"
        debug "XX - nom: "+nommodule
        debug "XX - path: "+modulepath
        i << new(
          :ensure => :present,
          :name   => nommodule,
          :path   => modulepath
        )
      end
    end
    debug "END loop slapcat"
    i
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
    file = Tempfile.new('openldap_module_init', '/tmp')
    begin
      file << "dn: cn=module,cn=config\n"
      file << "changetype: add\n"
      file << "objectclass: olcModuleList\n"
      file << "cn: module\n"
      file << "olcModuleLoad: #{resource[:name]}\n"
      file << "olcModulePath: #{resource[:path]}\n"
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
    @property_hash[:ensure] = :present
  end

  def path
    debug "path"
    @property_hash[:path]
  end

  def path=(value)
    debug "set value"
    file = Tempfile.new('openldap_module_path', '/tmp')
    begin
      if @property_hash[:path] == ''
        file << "dn: cn=module,cn=config\n"
        file << "changetype: add\n"
        file << "objectClass: olcModuleList\n"
        file << "olcModulePath: #{value}\n"
        # dn: cn=module,cn=config
        # changetype: add
        # objectClass: olcModuleList
        # cn: module
        # olcModulePath: /usr/lib64/openldap
        # olcModuleLoad: syncprov.la
      else
        # TODO: fer add si no existia
        file << "dn: cn=module,cn=config\n"
        file << "changetype: modify\n"
        file << "replace: olcModulePath\n"
        file << "olcModulePath: #{value}\n"
        # dn: cn=module,cn=config
        # changetype: add
        # objectClass: olcModuleList
        # cn: module
        # olcModulePath: /usr/lib64/openldap
        # olcModuleLoad: syncprov.la
      end
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
    @property_hash[:path] = value
  end

end
# [root@centos7 ~]# ldapsearch -Y EXTERNAL -H ldapi:/// -b cn=module,cn=config  '(objectClass=olcModuleList)'
# SASL/EXTERNAL authentication started
# SASL username: gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth
# SASL SSF: 0
# # extended LDIF
# #
# # LDAPv3
# # base <cn=module,cn=config> with scope subtree
# # filter: (objectClass=olcModuleList)
# # requesting: ALL
# #
#
# # search result
# search: 2
# result: 32 No such object
# matchedDN: cn=config
#
# # numResponses: 1
# [root@centos7 ~]#



# cat <<EOF | ldapmodify -Y EXTERNAL -H ldapi:///
# dn: cn=module,cn=config
# changetype: add
# objectClass: olcModuleList
# cn: module
# olcModulePath: /usr/lib64/openldap
# olcModuleLoad: syncprov.la
# EOF
#
# cat <<EOF | ldapadd -Y EXTERNAL -H ldapi:///
# dn: cn=module,cn=config
# cn: module
# objectclass: olcModuleList
# olcmodulepath: /usr/lib64/openldap
# olcmoduleload: memberof
