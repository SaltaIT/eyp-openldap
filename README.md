# openldap

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with openldap](#setup)
    * [What openldap affects](#what-openldap-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with openldap](#beginning-with-openldap)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

Installs OpenLDAP in standalone/master/slave/multimaster mode

## Module Description

Installs OpenLDAP, initializes it's database and configure it in standalone/master/slave/multimaster mode

## Setup

### What openldap affects

* Installs openldap, openldap-clients, openldap-servers

### Setup Requirements **OPTIONAL**

If your module requires anything extra before setting up (pluginsync enabled,
etc.), mention it here.

### Beginning with openldap

To setup a standalone OpenLDAP using dc=systemadmin,dc=es as RootDN with cn=admin,dc=systemadmin,dc=es / 123password:

```puppet
node 'ldap'
{
        class { 'openldap':
                base => 'dc=systemadmin,dc=es',
                admin => 'admin',
                adminpassword => '123password',
                oname => 'systemadmin.es rulez',
        }
}
```

To setup a OpenLDAP in master mode:

```puppet
node 'ldap'
{
        class { 'openldap':
                base => 'dc=systemadmin,dc=es',
                admin => 'admin',
                adminpassword => '123password',
                oname => 'systemadmin.es rulez',
                isMaster => true,
        }
}
```

To setup a OpenLDAP in slave mode:

```puppet
node 'ldapslave1','ldapslave2'
{
        class { 'openldap':
                base => 'dc=systemadmin,dc=es',
                admin => 'admin',
                adminpassword => '123password',
                oname => 'systemadmin.es rulez',
                masterinfo=> [ "192.168.96.250" ],
        }
}
```

To setup a OpenLDAP un multimaster mode:
```puppet
#LDAP-MASTER-1
node 'ldapmm1'
{
        class { 'openldap':
                base => 'dc=systemadmin,dc=es',
                admin => 'admin',
                adminpassword => '123password',
                oname => 'systemadmin.es rulez',
                isMaster => true,
                serverid => 1,
                mm => [ "10.10.10.2" ],
        }
}

#LDAP-MASTER-2
node 'ldapmm2'
{
        class { 'openldap':
                base => 'dc=systemadmin,dc=es',
                admin => 'admin',
                adminpassword => '123password',
                oname => 'systemadmin.es rulez',
                isMaster => true,
                serverid => 2,
                mm => [ "10.10.10.1" ],
        }
}
```

To setup LDAP with mdb backend and TLS enabled:
```puppet
class { 'openldap':
  base => 'o=AOP,ou=system',
  admin => 'Manager',
  adminpassword => 'cacadevaca',
  oname => 'admin',
  isMaster => true,
  backend => 'mdb',
  mdbsize => 12345678,
  tlsca => 'puppet:///openldap/masterauth/ccc-ca.crt',
  tlscert => 'puppet:///openldap/masterauth/ldap-master-01.crt',
  tlspk => 'puppet:///openldap/masterauth/ldap-master-01.key.pem',
}
```

## Usage

Use openldap to setup the deamon:

```puppet
        class { 'openldap':
                base => 'dc=systemadmin,dc=es',
                admin => 'admin',
                adminpassword => '123password',
                oname => 'systemadmin.es rulez',
        }
```

Configure a backup script

```puppet
	openldap::backupscript { 'backup':
		destination => '/backup',
		logdir => '/backup',
		mailto => 'spam@example.com',
		retention => 10,
		idhost => 'someID',
		hour => 2,
		minute => 0,
	}
```

Add indexes:

```puppet
	class { 'openldap::indexes':
		indexes => [
			'objectClass eq,pres',
			'ou,cn,mail,surname,givenname eq,pres,sub',
			'entryUUID eq',
			'entryCSN eq',
			'default sub',
			#'aopVehicleID',
			'uid eq',
			'uidNumber eq',
			'gidNumber eq',
			'memberUid eq',
			],
	}
```

## Reference

###Classes

####Public classes

* `openldap`
* `openldap::indexes`

####Public defines
* `openldap::backupscript`

###Parameters

####openldap

#####`chainingoverlay`

 Incompatible with `updateref`

#####`updateref`

 Incompatible with `chainingoverlay`

## Limitations

Tested in CentOS 6

## Development

Since your module is awesome, other users will want to play with it. Let them
know what the ground rules for contributing are.

## Release Notes/Contributors/Etc **Optional**

If you aren't using changelog, put your release notes here (though you should
consider using changelog). You may also add any additional sections you feel are
necessary or important to include here. Please use the `## ` header.
