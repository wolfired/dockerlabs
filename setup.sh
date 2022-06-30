host_workspace=${1:?'指定工作目录'}
host_ip=${2:?'指定主机IP'}

function main() {
    echo
    echo 'enter main'

    yq e '.services.*.name' ./dats.yml | while read -r service; do
        local guest_dns_ip=`yq e ".dns" ./dats.yml`
        local guest_name=`yq e ".services.$service.name" ./dats.yml`
        local guest_ip=`yq e ".services.$service.ip" ./dats.yml`
        local enable=`yq e ".services.$service.enable" ./dats.yml`

        if [[ ! -d ./$guest_name ]]; then
            echo "$guest_name do not exist"
            continue
        fi

        if (( 0 == $enable )); then
            continue
        fi

        local guest_workspace=$host_workspace/$guest_name

        mkdir -p $guest_workspace

        cp -vuR ./$guest_name/. $guest_workspace/

        sed -i "s#{{host_workspace}}#$host_workspace#g" $guest_workspace/docker-compose.yml
        sed -i "s#{{host_ip}}#$host_ip#g" $guest_workspace/docker-compose.yml
        sed -i "s#{{guest_dns_ip}}#$guest_dns_ip#g" $guest_workspace/docker-compose.yml
        sed -i "s#{{guest_ip}}#$guest_ip#g" $guest_workspace/docker-compose.yml

        case $guest_name in
        coredns)
            local port_udp_guest=`yq e ".services.$service.port_udp_guest" ./dats.yml`
            local port_udp_host=`yq e ".services.$service.port_udp_host" ./dats.yml`
            local port_tcp_guest=`yq e ".services.$service.port_tcp_guest" ./dats.yml`
            local port_tcp_host=`yq e ".services.$service.port_tcp_host" ./dats.yml`
            local port_health_guest=`yq e ".services.$service.port_health_guest" ./dats.yml`
            local port_health_host=`yq e ".services.$service.port_health_host" ./dats.yml`

            sed -i "s#{{port_udp_guest}}#$port_udp_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_udp_host}}#$port_udp_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_tcp_guest}}#$port_tcp_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_tcp_host}}#$port_tcp_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_health_guest}}#$port_health_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_health_host}}#$port_health_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_health_guest}}#$port_health_guest#g" $guest_workspace/cfgs/Corefile
            ;;
        nginx)
            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`
            local port_web_host=`yq e ".services.$service.port_web_host" ./dats.yml`
            local port_ssl_guest=`yq e ".services.$service.port_ssl_guest" ./dats.yml`
            local port_ssl_host=`yq e ".services.$service.port_ssl_host" ./dats.yml`

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_web_host}}#$port_web_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_ssl_guest}}#$port_ssl_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_ssl_host}}#$port_ssl_host#g" $guest_workspace/docker-compose.yml
            ;;
        gitea)
            local port_ssh_guest=`yq e ".services.$service.port_ssh_guest" ./dats.yml`
            local port_ssh_host=`yq e ".services.$service.port_ssh_host" ./dats.yml`
            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`
            local port_web_host=`yq e ".services.$service.port_web_host" ./dats.yml`

            sed -i "s#{{port_ssh_guest}}#$port_ssh_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_ssh_host}}#$port_ssh_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_web_host}}#$port_web_host#g" $guest_workspace/docker-compose.yml
            ;;
        drone)
            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`
            local port_web_host=`yq e ".services.$service.port_web_host" ./dats.yml`

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_web_host}}#$port_web_host#g" $guest_workspace/docker-compose.yml
            ;;
        clash)
            local port_proxy_guest=`yq e ".services.$service.port_proxy_guest" ./dats.yml`
            local port_proxy_host=`yq e ".services.$service.port_proxy_host" ./dats.yml`

            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`
            local port_web_host=`yq e ".services.$service.port_web_host" ./dats.yml`

            sed -i "s#{{port_proxy_guest}}#$port_proxy_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_proxy_host}}#$port_proxy_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $guest_workspace/docker-compose.yml
            sed -i "s#{{port_web_host}}#$port_web_host#g" $guest_workspace/docker-compose.yml

            sed -i "s#{{port_proxy_guest}}#$port_proxy_guest#g" $guest_workspace/config.yaml
            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $guest_workspace/config.yaml
            ;;
        *)
            echo 'nothing to do'
            ;;
        esac
    done

    echo 'leave main'
    echo
}

function handle_nginx() {
    echo
    echo 'enter handle_nginx'

    local target_service=nginx

    local enable=`yq e ".services.$target_service.enable" ./dats.yml`
    if (( 0 == $enable )); then
        return
    fi

    yq e '.services.*.name' ./dats.yml | while read -r service; do
        local guest_name=`yq e ".services.$service.name" ./dats.yml`
        local guest_ip=`yq e ".services.$service.ip" ./dats.yml`
        local enable=`yq e ".services.$service.enable" ./dats.yml`

        if [[ $target_service == $service ]]; then
            continue
        fi

        if (( 0 == $enable )); then
            continue
        fi

        local guest_workspace=$host_workspace/$guest_name

        if [[ ! -d $guest_workspace ]]; then
            echo "$guest_workspace do not exist"
            continue
        fi

        if [[ ! -f $guest_workspace/$guest_name.conf ]]; then
            echo "$guest_workspace/$guest_name.conf do not exist"
            continue
        fi

        cp -vu $guest_workspace/$guest_name.conf $host_workspace/$target_service/conf/conf.d/

        sed -i "s#{{guest_name}}#$guest_name#g" $host_workspace/$target_service/conf/conf.d/$guest_name.conf
        sed -i "s#{{guest_ip}}#$guest_ip#g" $host_workspace/$target_service/conf/conf.d/$guest_name.conf

        case $guest_name in
        coredns)
            local port_health_guest=`yq e ".services.$service.port_health_guest" ./dats.yml`

            sed -i "s#{{port_health_guest}}#$port_health_guest#g" $host_workspace/$target_service/conf/conf.d/$guest_name.conf
            ;;
        gitea)
            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $host_workspace/$target_service/conf/conf.d/$guest_name.conf
            ;;
        drone)
            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $host_workspace/$target_service/conf/conf.d/$guest_name.conf
            ;;
        clash)
            local port_web_guest=`yq e ".services.$service.port_web_guest" ./dats.yml`

            sed -i "s#{{port_web_guest}}#$port_web_guest#g" $host_workspace/$target_service/conf/conf.d/$guest_name.conf
            ;;
        *)
            echo 'nothing to do'
            ;;
        esac
    done

    mkdir -p $host_workspace/$target_service/conf/encrypt/archive
    find $host_workspace/$target_service/conf/encrypt/archive -mindepth 1 -maxdepth 1 -print | while read -r line; do
        local dir_name=`basename $line`
        mkdir -p $host_workspace/$target_service/conf/encrypt/live/$dir_name

        local ssl_files=(cert chain fullchain privkey)
        for ssl_file in ${ssl_files[@]}; do
            local target_name=$(basename `ls $line/$ssl_file* | sort -V | tail -n 1` | grep -oP '[a-z\d]+?(?=\.)' | grep -oP '[a-z]+')

            pushd $host_workspace/$target_service/conf/encrypt/live/$dir_name 1>/dev/null 2>&1 && \
            ln -sf ../../archive/$dir_name/$(basename `ls $line/$ssl_file* | sort -V | tail -n 1` | grep -oP '[a-z\d]+?(?=\.)').pem $host_workspace/$target_service/conf/encrypt/live/$dir_name/$target_name.pem && \
            popd 1>/dev/null 2>&1
        done
    done

    echo 'leave handle_nginx'
    echo    
}

function handle_clash() {
    echo
    echo 'enter handle_clash'

    local target_service=clash

    local enable=`yq e ".services.$target_service.enable" ./dats.yml`
    if (( 0 == $enable )); then
        return
    fi

    pushd $host_workspace/$target_service 1>/dev/null 2>&1

    if [[ ! -d $host_workspace/$target_service/yacd ]]; then
        git clone --depth 1 https://github.com/haishanh/yacd.git
    fi


    if [[ -d $host_workspace/$target_service/yacd && ! -d $host_workspace/$target_service/yacd/public ]]; then
        pushd $host_workspace/$target_service/yacd 1>/dev/null 2>&1
        npm i -g pnpm && pnpm i && pnpm build
        popd 1>/dev/null 2>&1
    fi

    popd 1>/dev/null 2>&1

    echo 'leave handle_nginx'
    echo  
}

main
handle_nginx
handle_clash
