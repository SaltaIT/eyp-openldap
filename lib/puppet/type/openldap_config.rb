Puppet::Type.newtype(:openldap_config) do

  ensurable

  newparam(:name, :namevar => true) do
    desc 'attribute to manage'
    validate do |value|
      unless value.is_a?(String)
        raise Pupper::Error,
          "not a string, modafuca"
      end
    end
  end

  newproperty(:value) do
    validate do |value|
      unless value.is_a?(String)
        raise Pupper::Error,
          "not a string, modafuca"
      end
    end
  end

end
