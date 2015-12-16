require 'spec_helper'
describe 'openldap' do

  context 'with defaults for all parameters' do
    it { should contain_class('openldap') }
  end
end
