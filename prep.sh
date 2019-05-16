#!/bin/bash

main() {
	read -r -p "Is this a Master or Slave node? (slave) " node_choice </dev/tty
	case "$node_choice" in
	master | Master) node_type=master ;;
	slave | Slave) node_type=slave ;;
	*) node_type=slave ;;
	esac

	if ! [ -x "$(command -v docker)" ]; then
		echo "Installing Docker"
		curl -sSL get.docker.com | sh
	fi

	if uname -a | grep hypriot; then
		os_type=hypriot
	elif [ "$(lsb_release -si)" = 'Raspbian' ]; then
		os_type=raspbian
	fi

	if [[ "$os_type" == "raspbian" ]]; then
		sudo usermod pi -aG docker
	elif [[ "$os_type" == "hypriot" ]]; then
		sudo usermod pirate -aG docker
	else
		echo "OS type not known"
		exit 1
	fi

	installed_docker_version=$(apt-cache policy docker-ce | grep "Installed" | cut -d ":" -f 3)
	echo
	echo "Docker, $installed_docker_version is currently installed."
	read -r -p "Do you need to install a different version? (y/n) " docker_choice </dev/tty
	echo
	case "$docker_choice" in
	y | Y)
		apt-cache madison docker-ce | cut -d "|" -f 3 &&
			echo
		read -r -p "Which Docker version do you want to install (e.g. 18.05.0~ce~3-0~ubuntu)? " docker_version </dev/tty &&
			sudo apt-get install -qy docker-ce="$docker_version"
		;;
	n | N) ;;
	*) ;;
	esac

	echo

	echo "Disabling Swap"
	sudo dphys-swapfile swapoff &&
	sudo dphys-swapfile uninstall &&
	sudo update-rc.d dphys-swapfile remove

	echo

	echo "Installing Kubernetes"
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - &&
		echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list &&
		sudo apt-get update -q

	echo

	installed_kuber_version=$(apt-cache policy kubeadm | grep "Installed" | cut -d ":" -f 2)
	if ! [ -x "$(command -v kubeadm)" ]; then
		echo "Kubeadm, $installed_kuber_version is currently installed."
	fi
	read -r -p " Use latest Kubeadm version? (y/n) " kuber_choice </dev/tty
	case "$kuber_choice" in
	n | N)
		read -r -p "Which version of Kubernetes do you want to install (e.g. 1.10.2-00)? " kuber_version </dev/tty
		sudo apt-get install -qy kubeadm="$kuber_version" kubectl="$kuber_version" kubelet="$kuber_version"
		;;
	y | Y) sudo apt-get install -qy kubeadm kubectl kubelet ;;
	esac

	echo

	echo "Docker $(apt-cache policy docker-ce | grep "Installed" | cut -d ":" -f 3) is installed"
	read -r -p "Do you want to prevent docker-ce from being upgraded? (y/n) " upgrade_docker </dev/tty
	case $upgrade_docker in
	y | Y)
		echo "docker-ce hold" | sudo dpkg --set-selections
		echo "done"
		;;
	n | N) ;;
	*) ;;
	esac

	echo

	echo "Kubeadm $(apt-cache policy kubeadm | grep "Installed" | cut -d ":" -f 2 | awk '{$1=$1;print}') is installed"
	read -r -p "Do you want to prevent kubeadm from being upgraded? (y/n) " upgrade_kuber </dev/tty
	case "$upgrade_kuber" in
	y | Y)
		echo "kubeadm hold" | sudo dpkg --set-selections
		echo "done"
		;;
	n | N) ;;
	*) ;;
	esac

	echo

	if ! [ -x "$(grep "cgroup" /boot/cmdline.txt)" ]; then
	echo "Backing up cmdline.txt to /boot/cmdline_backup.txt"
	sudo cp /boot/cmdline.txt /boot/cmdline_backup.txt
	echo
	echo Adding " cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory " to /boot/cmdline.txt
	orig="$(head -n1 /boot/cmdline.txt) cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"
	echo "$orig" | sudo tee /boot/cmdline.txt
	fi
	
	if [[ "$node_type" == "master" ]]; then
		echo "Removing \"KUBELET_NETWORK_ARGS\" from 10-kubeadm.conf"
		sudo sed -i '/KUBELET_NETWORK_ARGS=/d' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
	elif [[ "$node_type" == "slave" ]]; then
	fi
	
	
	echo "Start initial cluster"
	wifiIP = $(ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
	sudo kubeadm init --pod-network-cidr=10.244.10.0/16 --apiserver-advertise-address=$wifiIP 
	mkdir -p $HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
	sudo chown $(id -u):$(id -g) $HOME/.kube/config
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	
	echo "Please reboot."
	exit 0
}
main
