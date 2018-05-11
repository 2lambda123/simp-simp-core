require 'spec_helper_integration'
require 'beaker/puppet_install_helper'

# Create a Puppetfile for R10K from module
# portion of a simp-core Puppetfile.<tracking|stable>.
# Returns Puppetfile content
def create_r10k_puppetfile(simp_core_puppetfile)
  r10k_puppetfile = []
  lines = IO.readlines(simp_core_puppetfile)
  modules_section = false
  lines.each do |line|
     if line.match(/^moduledir/)
       if line.match(/^moduledir 'src\/puppet\/modules'/)
         modules_section = true
       else
         modules_section = false
       end
       next
     end
     r10k_puppetfile << line if modules_section
  end
  r10k_puppetfile.join  # each line already contains a \n
end

test_name 'puppetserver via r10k'

describe 'install environment via r10k and puppetserver' do

  masters = hosts_with_role(hosts, 'master')

  hosts.each do |host|
    it 'should set the root password' do
      on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
      on(host, 'echo password | passwd root --stdin')
    end
    it 'should set up needed repositories' do
      host.install_package('epel-release')
      on(host, 'curl -s https://packagecloud.io/install/repositories/simp-project/6_X_Dependencies/script.rpm.sh | bash')
    end
  end

  context 'install and start a standard puppetserver' do
    masters.each do |master|
      it 'should install the r10k gem' do
        master.install_package('git')
        on(master, 'puppet resource package r10k ensure=present provider=puppet_gem')
      end

      it 'should install puppetserver' do
        master.install_package('puppetserver')
      end

      it 'should start puppetserver' do
        on(master, 'puppet resource service puppetserver ensure=running')
      end

      it 'should enable trusted_server_facts' do
        on(master, 'puppet config --section master set trusted_server_facts true')
      end
    end
  end

  context 'install modules via r10k' do
    it 'should create a Puppetfile in $codedir from Puppetfile.tracking' do
      file_content = create_r10k_puppetfile('Puppetfile.tracking')
      create_remote_file(master, '/etc/puppetlabs/code/environments/production/Puppetfile',
        file_content)
    end

    it 'should install the Puppetfile' do
      on(master, 'cd /etc/puppetlabs/code/environments/production; /opt/puppetlabs/puppet/bin/r10k puppetfile install', :accept_all_exit_codes => true)
      on(master, 'cd /etc/puppetlabs/code/environments/production; /opt/puppetlabs/puppet/bin/r10k puppetfile install')
      on(master, 'chown -R root.puppet /etc/puppetlabs/code/environments/production/modules')
      on(master, 'chmod -R g+rX /etc/puppetlabs/code/environments/production/modules')
    end
  end
end
