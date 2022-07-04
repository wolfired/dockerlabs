root_ws="$(dirname $0)"

host_ws=${1:?'指定工作目录'}
host_ip=${2:?'指定主机IP'}
exec_cmd=${3:?'指定执行命令: services_setup, services_start, services_stop'}

function replace_service_cfg() {
    local service=${1:?'请指定服务'}
    local cfgfile=${2:?'请指定配置'}

    cat $cfgfile | grep -oP '\{\{\..+?\}\}' | while read -r placeholder; do
        local key=`echo $placeholder | grep -oP '(?<=\{\{).+?(?=\}\})'`
        local value=`yq e ".services.$service$key" $root_ws/dats.yml`
        sed -i "s#$placeholder#$value#" $cfgfile
    done
}

function get_guest_dns_ip() {
    yq e '.services.coredns.ip' $root_ws/dats.yml
}

function setup_nginx() {
    echo
    echo 'enter setup_nginx'

    local target_service=nginx

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        if [[ $target_service == $service ]]; then
            continue
        fi

        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`

        if (( 0 == $enable )); then
            echo "$service disabled"
            continue
        fi

        if [[ ! -d $host_ws/$service ]]; then
            echo "$host_ws/$service do not exist"
            continue
        fi

        if [[ ! -f $host_ws/$service/$service.conf ]]; then
            echo "$host_ws/$service/$service.conf do not exist"
            continue
        fi

        cp -vu $host_ws/$service/$service.conf $host_ws/$target_service/conf/conf.d/

        replace_service_cfg $service $host_ws/$target_service/conf/conf.d/$service.conf
    done

    mkdir -p $host_ws/$target_service/html/share

    mkdir -p $host_ws/$target_service/conf/encrypt/archive
    find $host_ws/$target_service/conf/encrypt/archive -mindepth 1 -maxdepth 1 -print | while read -r line; do
        local dir_name=`basename $line`
        mkdir -p $host_ws/$target_service/conf/encrypt/live/$dir_name

        local ssl_files=(cert chain fullchain privkey)
        for ssl_file in ${ssl_files[@]}; do
            local target_name=$(basename `ls $line/$ssl_file* | sort -V | tail -n 1` | grep -oP '[a-z\d]+?(?=\.)' | grep -oP '[a-z]+')

            pushd $host_ws/$target_service/conf/encrypt/live/$dir_name 1>/dev/null 2>&1 && \
            ln -sf ../../archive/$dir_name/$(basename `ls $line/$ssl_file* | sort -V | tail -n 1` | grep -oP '[a-z\d]+?(?=\.)').pem $host_ws/$target_service/conf/encrypt/live/$dir_name/$target_name.pem && \
            popd 1>/dev/null 2>&1
        done
    done

    echo 'leave setup_nginx'
    echo    
}

function setup_clash() {
    echo
    echo 'enter setup_clash'

    local target_service=clash

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    pushd $host_ws/$target_service 1>/dev/null 2>&1

    if [[ ! -d $host_ws/$target_service/yacd ]]; then
        git clone --depth 1 https://github.com/haishanh/yacd.git
    fi

    if [[ -d $host_ws/$target_service/yacd && ! -d $host_ws/$target_service/yacd/public ]]; then
        pushd $host_ws/$target_service/yacd 1>/dev/null 2>&1
        npm i -g pnpm && pnpm i && pnpm build
        popd 1>/dev/null 2>&1
    fi

    popd 1>/dev/null 2>&1

    echo 'leave setup_nginx'
    echo  
}

function services_setup() {
    echo
    echo 'enter services_setup'

    local guest_dns_ip=`get_guest_dns_ip`

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`

        if (( 0 == $enable )); then
            echo "$service disabled"
            continue
        fi

        if [[ ! -d $root_ws/$service ]]; then
            echo "$service do not exist"
            continue
        fi

        mkdir -p $host_ws/$service

        cp -vuR $root_ws/$service/. $host_ws/$service/

        sed -i "s#{{host_ws}}#$host_ws#g" $host_ws/$service/docker-compose.yml
        sed -i "s#{{host_ip}}#$host_ip#g" $host_ws/$service/docker-compose.yml
        sed -i "s#{{guest_dns_ip}}#$guest_dns_ip#g" $host_ws/$service/docker-compose.yml

        replace_service_cfg $service $host_ws/$service/.env
        replace_service_cfg $service $host_ws/$service/docker-compose.yml

        case $service in
        coredns)
            replace_service_cfg $service $host_ws/$service/cfgs/Corefile
            ;;
        nginx)
            ;;
        gitea)
            ;;
        drone)
            ;;
        clash)
            replace_service_cfg $service $host_ws/$service/config.yaml
            ;;
        u3dacc)
            ;;
        *)
            ;;
        esac
    done

    setup_nginx
    setup_clash

    echo 'leave services_setup'
    echo
}

function services_start() {
    echo
    echo 'enter services_start'

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`
        local start=`yq e ".services.$service.start" $root_ws/dats.yml`

        if (( 0 == $enable || 0 == $start )); then
            echo "$service disabled or distart"
            continue
        fi

        if [[ ! -d $host_ws/$service ]]; then
            echo "$service do not exist"
            continue
        fi

        pushd $host_ws/$service 1>/dev/null 2>&1

        docker-compose up -d

        popd 1>/dev/null 2>&1
    done

    echo 'leave services_start'
    echo
}

function services_stop() {
    echo
    echo 'enter services_stop'

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`
        local start=`yq e ".services.$service.start" $root_ws/dats.yml`

        if (( 0 == $enable || 0 == $start )); then
            echo "$service disabled or distart"
            continue
        fi

        if [[ ! -d $host_ws/$service ]]; then
            echo "$service do not exist"
            continue
        fi

        pushd $host_ws/$service 1>/dev/null 2>&1

        docker-compose down

        popd 1>/dev/null 2>&1
    done

    echo 'leave services_stop'
    echo
}

$exec_cmd
