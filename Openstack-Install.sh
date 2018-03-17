#!/bin/bash
########### INSTALL OPENSTACK QUEENS #############
########### VARIABLES ##########

NETINT="em1"
IPADRESS="192.168.2.3"
MASK="255.255.255.0"
GATEWAY="192.168.2.254"

######################## START INSTALL #####################
echo "Realizando pré requisitos"
	sleep 5
######## Disable Firewalld and NetworkManager services ##############
echo "desabilitando firewalld e Network Manager"
	systemctl disable firewalld
		systemctl stop firewalld
			systemctl disable NetworkManager
				systemctl enable network           ############ not change
					systemctl start network    ############ not change
################# Change SELINUX Mode ##################
echo "configurando SELINUX para permissive"
	sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux
		setenforce 0
################ Install Openstack repo and dependences packages #############
echo "instalando repositorio do openstack e seus pacotes."
	yum install -y https://rdoproject.org/repos/rdo-release.rpm
			yum update -y
				yum install openstack-packstack -y				
############### Install OVS ##############
echo "Install OVS"
	yum install openvswitch -y
########### Create and configuration bridge interface #######################
echo "criando brigde br-ex"
	touch /etc/sysconfig/network-scritps/ifcfg-br-ex
		cat >/etc/sysconfig/network-scripts/ifcfg-br-ex <<EOL
			DEVICE=br-ex
			DEVICETYPE=ovs
			TYPE=OVSBridge
			BOOTPROTO=static
			IPADDR=$IPADRESS
			NETMASK=$MASK
			GATEWAY=$GATEWAY
			DNS1=8.8.8.8
			ONBOOT=yes
EOL
########## Create backup network interface configuration ###########
cp -f /etc/sysconfig/network-scripts/ifcfg-$NETINT /etc/sysconfig/network-scripts/ifcfg-$NETINT.BACKUP
echo "criando configuração para a placa de rede física $NETINT"
########## Change interface configuration ##############
	cat >/etc/sysconfig/network-scripts/ifcfg-$NETINT <<EOL
		DEVICE="$NETINT"
		TYPE="OVSPort"
		DEVICETYPE=ovs
		OVS_BRIDGE=br-ex
		ONBOOT=yes
		BOOTPROTO="none"
EOL
######### Restart service ###########
echo "Restart network service"
	systemctl restart network
######### Packstack ###############
echo "Deploy Openstack inicializating"
	packstack --allinone --provision-demo=n --os-neutron-ovs-bridge-mappings=extnet:br-ex --os-neutron-ovs-bridge-interfaces=br-ex:$NETINT --os-neutron-ml2-type-drivers=vxlan,flat
		sleep 30
########### Network configureation with neutron shell
echo "Loggin Openstack Admin"
	source /root/keystone_admin
		sleep 5
########### Step2
echo "Criando rede external"
	neutron net-create external_network --provider:network_type flat --provider:physical_network extnet  --router:external
		sleep 5
########### Setp3
echo "Criando subnet externa..."
echo "Pool de ips 192.168.10.230 - 192.168.10.235"
	neutron subnet-create --name public_subnet --allocation-pool=start=192.168.10.230,end=192.168.10.235 --gateway=192.168.10.1 external_network 192.168.10.0/24
		sleep 5
########## Step4
echo "Criando roteador"
	neutron router-create router1
echo "Criando rede privada"
	neutron net-create private_network
		neutron subnet-create --name private_subnet private_network 192.168.100.0/24
echo "Atachando roteador na rede privada"
	neutron router-interface-add router1 private_subnet
echo "redes configruadas"
