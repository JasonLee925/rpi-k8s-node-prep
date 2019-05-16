echo "Start initial cluster"
wifiIP = $(ip addr show wlan0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1)
sudo kubeadm init --pod-network-cidr=10.244.10.0/16 --apiserver-advertise-address=$wifiIP 
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
