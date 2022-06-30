dockerlabs
==========

```bash

# 创建网络
sudo docker network create --gateway 192.168.1.1 --subnet 192.168.1.0/24 lanet

# Linux
bash ./setup.sh $HOME/workspace_docker `ip -o route get to 223.5.5.5 | grep -oP '(?<=src )\d+\.\d+\.\d+\.\d+'`

# 一键启动
for value in coredns nginx gitea; do
    pushd $HOME/workspace_docker/$value 1>/dev/null 2>&1 && \
    docker-compose up -d && \
    popd 1>/dev/null 2>&1
done

# 一键关闭
for value in gitea nginx coredns; do
    pushd $HOME/workspace_docker/$value 1>/dev/null 2>&1 && \
    docker-compose down && \
    popd 1>/dev/null 2>&1
done

```
