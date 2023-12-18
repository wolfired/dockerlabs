dockerlabs
==========

```bash

# 创建网络
sudo docker network create --gateway 192.168.1.1 --subnet 192.168.1.0/24 lanet

# 依赖go-yq
sudo pacman -S go-yq

# Docker使用代理
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo touch /etc/systemd/system/docker.service.d/proxy.conf
cat <<EOF >> /etc/systemd/system/docker.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=http://192.168.73.140:1080/"
Environment="HTTPS_PROXY=http://192.168.73.140:1080/"
Environment="NO_PROXY=localhost,127.0.0.1,192.168.73.0/24,192.168.100.0/24"
EOF 

# unset enable, start
sed -i "s#\(enable: \).*#\10#g" ./dats.yml && sed -i "s#\(start: \).*#\10#g" ./dats.yml

# set enable, start
sed -i "s#\(enable: \).*#\11#g" ./dats.yml && sed -i "s#\(start: \).*#\11#g" ./dats.yml

# set domain to vyorz
sed -i "s#\(domain: '\).*\('\)#\1vyorz\2#g" ./dats.yml

# set domain to wolfired
sed -i "s#\(domain: '\).*\('\)#\1wolfired\2#g" ./dats.yml

# Linux
sudo -E bash `pwd`/main.sh $HOME/workspace_docker `ip -o route get to 223.5.5.5 | grep -oP '(?<=src )\d+\.\d+\.\d+\.\d+'`

```

# Onedev安装svn

```bash 

# outside onedev container
sudo docker exec -it 'Change to your CONTAINER ID' bash

# inside onedev container
apt update
apt install subversion

# outside onedev container
sudo docker commit 'Change to your CONTAINER ID'
sudo docker tag 'Change to your IMAGE ID' 1dev/server:svn

```

