dockerlabs
==========

```bash

# 创建网络
sudo docker network create --gateway 192.168.1.1 --subnet 192.168.1.0/24 lanet

# Linux
sudo bash `pwd`/main.sh $HOME/workspace_docker `ip -o route get to 223.5.5.5 | grep -oP '(?<=src )\d+\.\d+\.\d+\.\d+'`

```
