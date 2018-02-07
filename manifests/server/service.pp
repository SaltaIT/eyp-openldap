class openldap::server::service inherits openldap::server {

  #
  validate_bool($openldap::server::manage_docker_service)
  validate_bool($openldap::server::manage_service)
  validate_bool($openldap::server::service_enable)

  validate_re($openldap::server::service_ensure, [ '^running$', '^stopped$' ], "Not a valid daemon status: ${openldap::server::service_ensure}")

  $is_docker_container_var=getvar('::eyp_docker_iscontainer')
  $is_docker_container=str2bool($is_docker_container_var)

  if( $is_docker_container==false or
      $openldap::server::manage_docker_service)
  {
    if($openldap::server::manage_service)
    {
      service { 'slapd':
        ensure => $openldap::server::service_ensure,
        enable => $openldap::server::service_enable,
      }
    }
  }
}
