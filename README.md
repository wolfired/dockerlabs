dockerlabs
==========

```bash

# 创建网络
sudo docker network create --gateway 192.168.1.1 --subnet 192.168.1.0/24 lanet

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
sudo docker tag 'Change to your CONTAINER ID' 1dev/server:svn

```

