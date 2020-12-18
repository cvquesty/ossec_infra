#!/bin/bash
#===============================================================================
#
#          FILE: production.sh
#
#         USAGE: ./production
#
#   DESCRIPTION: Puppet VM Provisioning script for Vagrant to build production
#                node that includes a Puppet agent and an OSSEC client
#
#        AUTHOR: Jerald Sheets
#  ORGANIZATION: S & S Consulting Group
#       CREATED: 10/08/2020 16:14
#===============================================================================

# Kill the erroneous entry in /etc/hosts (Introduced by Virtualbox)
/bin/sed -i '/127.0.1.1 production.puppet.vm production/d' /etc/hosts

# Clean the Yum Cache
rm -fr /var/cache/yum/*
/usr/bin/yum clean all

# Update VM to latest version of Linux
yum -y update

# Bounce the network to trade out the Virtualbox IP
  /bin/systemctl restart network

# Disable the local firewall
/bin/systemctl stop firewalld
/bin/systemctl disable firewalld

# Install Puppet Labs Official Repository for CentOS 7
/bin/rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-7.noarch.rpm

# Install Puppet Server Components and Support Packages
/usr/bin/yum -y install puppet-agent

# Create a puppet.conf
cat >> /etc/puppetlabs/puppet/puppet.conf << 'EOF'
environment = production
certname = production.puppet.vm
server = master.puppet.vm
EOF

# Do initial Puppet Run
/opt/puppetlabs/puppet/bin/puppet agent -t

# Bounce the machine one more time for service
/usr/sbin/reboot

# Install the OSSEC Repo
yum -y install wget
wget -q -O - https://updates.atomicorp.com/installers/atomic | sudo NON_INT=1 bash

# Bounce the machine one more time for service
/usr/sbin/reboot

# Install OSSEC Repo
yum -y install wget
wget -q -O - https://updates.atomicorp.com/installers/atomic | sudo NON_INT=1 bash

# Install OSSEC Prerequisites
yum -y install zlib-devel pcre2-devel make gcc sqlite-devel openssl-devel libevent-devel

# Install OSSEC agent and server
yum -y install ossec-hids ossec-hids-agent
