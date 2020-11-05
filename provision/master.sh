#!/bin/bash -
#===============================================================================
#
#          FILE: master.sh
#
#         USAGE: ./master.sh
#
#   DESCRIPTION: Puppet VM Provisioning script for Vagrant
#
#        AUTHOR: YOUR NAME (Jerald Sheets),
#  ORGANIZATION: S & S Consulting Group
#       CREATED: 10/08/2020 16:14
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Kill the erroneous entry in /etc/hosts (Introduced by Virtualbox)
/bin/sed -i '/127.0.1.1 master.puppet.vm master/d' /etc/hosts

# Clean the Yum Cache
rm -fr /var/cache/yum/*
/usr/bin/yum clean all

# Update VM to latest version of Linux
yum -y update

# Install Puppet's Official Repository for RHEL/CentOS 7
rpm -Uvh https://yum.puppet.com/puppet6-release-el-7.noarch.rpm

# Install Puppet Server Components and Support Packages
/usr/bin/yum -y install puppetserver

# Start and Enable the Puppet Master
/bin/systemctl start puppetserver
/bin/systemctl enable puppetserver
/bin/systemctl start puppet
/bin/systemctl enable puppet

# Bounce the network to trade out the Virtualbox IP
/bin/systemctl restart network

# Install Git
/usr/bin/yum -y install git

# Install Needed Modules for system configuration
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-hiera
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-r10k
/opt/puppetlabs/puppet/bin/puppet module install -f puppet-make
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-concat
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-firewall
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-stdlib
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-ruby
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-gcc
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-inifile
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-vcsrepo
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-pe_gem
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-postgresql
/opt/puppetlabs/puppet/bin/puppet module install -f puppetlabs-git
/opt/puppetlabs/puppet/bin/puppet module install -f gentoo-portage

# Place the Hiera Configuration File
cat > /var/tmp/configure_hiera.pp << 'EOF'
class { 'hiera':
  hiera_version   => '5',
  hiera5_defaults => { "datadir" => "data", "data_hash" => "yaml_data"},
  hierarchy  => [
    {"name" => "Nodes yaml", "path" => "nodes/%{trusted.certname}.yaml"},
    {"name" => "Environments yaml", "path" => "environments/%{::environment}.yaml"},
    {"name" => "Common Defaults yaml", "path" => "common.yaml"},
  ],
}
EOF

# Place the directory environments config file
cat > /var/tmp/configure_directory_environments.pp << 'EOF'
#####                            #####
## Configure Directory Environments ##
#####                            #####

# Default for ini_setting resource:
Ini_setting {
  ensure => 'present',
  path   => "${::settings::confdir}/puppet.conf",
}

ini_setting { 'Configure Environmentpath':
  section => 'main',
  setting => 'environmentpath',
  value   => '$codedir/environments',
}

ini_setting { 'Configure Basemodulepath':
  section => 'main',
  setting => 'basemodulepath',
  value   => '$confdir/modules:/opt/puppetlabs/puppet/modules',
}

ini_setting { 'Master Agent Server':
  section => 'agent',
  setting => 'server',
  value   => 'master.puppet.vm',
}

ini_setting { 'Master Agent Certname':
  section => 'agent',
  setting => 'certname',
  value   => 'master.puppet.vm',
}
EOF

# Place the r10k configuration file
cat > /var/tmp/configure_r10k.pp << 'EOF'
class { 'r10k':
  version => '3.1.1',
  sources => {
    'puppet' => {
      'remote'  => 'https://github.com/cvquesty/ossec_control_repo',
      'basedir' => "${::settings::codedir}/environments",
      'prefix'  => false,
    }
  },
  manage_modulepath => false,
}
EOF

# Install and Configure autosign.conf for agents
cat > /etc/puppetlabs/puppet/autosign.conf << 'EOF'
*.puppet.vm
EOF

# Stop and disable iptables
  /bin/systemctl stop firewalld.service
  /bin/systemctl disable firewalld.service
  /bin/systemctl stop iptables.service
  /bin/systemctl disable iptables.service

# Then Configure Hiera
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_hiera.pp

# Configure R10k
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_r10k.pp

# Configure Directory Environments
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_directory_environments.pp

# Install and Configure PuppetDB
/opt/puppetlabs/puppet/bin/puppet module install puppetlabs-puppetdb --ignore-dependencies
/opt/puppetlabs/puppet/bin/puppet apply -e "include puppetdb" --http_connect_timeout=5m || true
/opt/puppetlabs/puppet/bin/puppet apply -e "include puppetdb::master::config" --http_connect_timeout=5m || true

# Initial r10k Deploy
/usr/bin/r10k deploy environment -pv

# Do Initial Puppet Run
/opt/puppetlabs/puppet/bin/puppet agent -t

# Bounce the machine one more time for service
/usr/sbin/reboot
