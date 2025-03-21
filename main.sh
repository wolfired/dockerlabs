root_ws="$(dirname $0)"

host_ws=${1:?'指定工作目录'}
host_ip=${2:?'指定主机IP'}
exec_cmd=${3:?'指定执行命令: services_setup, services_start, services_stop, services_restart'}

function color_msg() {
    local color=${1:?'(r)ed or (g)reen (b)lue (y)ellow (p)urple (c)yan'}

    if (( 2 > $# )); then
        return
    fi

    if [[ 'r' == $color ]]; then
        echo -e '\033[31m'${@:2}'\033[0m' # red
    elif [[ 'g' == $color ]]; then
        echo -e '\033[32m'${@:2}'\033[0m' # green
    elif [[ 'b' == $color ]]; then
        echo -e '\033[34m'${@:2}'\033[0m' # blue
    elif [[ 'y' == $color ]]; then
        echo -e '\033[33m'${@:2}'\033[0m' # yellow
    elif [[ 'p' == $color ]]; then
        echo -e '\033[35m'${@:2}'\033[0m' # purple
    elif [[ 'c' == $color ]]; then
        echo -e '\033[36m'${@:2}'\033[0m' # cyan
    else
        echo -e '\033[37m'${@:2}'\033[0m' # white
    fi
}

function select_service() {
    local ps3=${1:-'请选择服务'}

    local services=()

    for service in `yq e '.services.*.name' $root_ws/dats.yml`; do
        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`

        if (( 0 == $enable )); then
            continue
        fi

        if [[ ! -d $root_ws/$service ]]; then
            continue
        fi

        services+=($service)
    done

    PS3="$ps3(1-${#services[@]}): "
    select label in ${services[@]}; do
        local index=$(($REPLY-1))
        if (( 0 <= $index && $index < ${#services[@]} )); then
            echo ${services[$index]}
        else
            echo "Illegal Selection: $REPLY" 1>&2
            exit 1
        fi
        break
    done
}

function is_service_running() {
    local target_service=${1:?'请指定服务'}

    for service in `docker-compose ls | tail -n +2 | grep -oP '^\w+'`; do
        if [[ $target_service == $service ]]; then
            return 1
        fi
    done
    return 0
}

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

function gen_index() {
    local index=${1:?'请指定Index'}

cat <<< `

echo '<html>
    <head></head>
    <body>
        <h1>Tada ...</h1>
        <table>'

yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
    local enable=$(yq e ".services.$service.enable" $root_ws/dats.yml)
    local start=$(yq e ".services.$service.start" $root_ws/dats.yml)
    local name=$(yq e ".services.$service.name" $root_ws/dats.yml)
    local domain=$(yq e ".services.$service.domain" $root_ws/dats.yml)
    local li=$(yq e ".services.$service.li" $root_ws/dats.yml)
    if (( 0 == $enable || 0 == $start )) || [[ ! -n $li ]]; then
        continue
    fi
    echo "            $li" | sed "s#{{name}}#$name#g" | sed "s#{{domain}}#$domain#g"
done

echo '        </table>
    </body>
</html>

'

` > $index

}

function setup_nginx() {
    echo
    color_msg y 'enter setup_nginx'
    echo

    local target_service=nginx # 定制服务名

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    # 定制内容开始
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

        cp -v $host_ws/$service/$service.conf $host_ws/$target_service/conf/conf.d/

        replace_service_cfg $service $host_ws/$target_service/conf/conf.d/$service.conf
    done

    replace_service_cfg $target_service $host_ws/$target_service/conf/conf.d/default.conf

    mkdir -p $host_ws/$target_service/html/share

    mkdir -p $host_ws/$target_service/conf/encrypt/archive
    find $host_ws/$target_service/conf/encrypt/archive -mindepth 1 -maxdepth 1 -print | while read -r line; do
        local dir_name=`basename $line`
        local dir_name_without_num=`echo $dir_name | grep -oP '[a-z\.]+'`

        mkdir -p $host_ws/$target_service/conf/encrypt/live/$dir_name_without_num

        local ssl_files=(cert chain fullchain privkey)
        for ssl_file in ${ssl_files[@]}; do
            local target_name=$(basename `ls -c $line/ | grep -P ^$ssl_file | sort -V | tail -n 1` | grep -oP '[a-z0-9]+?(?=\.)')
            local target_name_without_num=`echo $target_name | grep -oP '[a-z]+'`

            pushd $host_ws/$target_service/conf/encrypt/live/$dir_name_without_num 1>/dev/null 2>&1 && \
            ln -sf ../../archive/$dir_name/$target_name.pem $host_ws/$target_service/conf/encrypt/live/$dir_name_without_num/$target_name_without_num.pem && \
            popd 1>/dev/null 2>&1
        done
    done

    gen_index $host_ws/$target_service/html/index.html

    # 定制内容结束

    echo
    color_msg y 'leave setup_nginx'
}

function setup_clash() {
    echo
    color_msg y 'enter setup_clash'
    echo

    local target_service=clash # 定制服务名

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    pushd $host_ws/$target_service 1>/dev/null 2>&1

    # 定制内容开始
    if [[ ! -d $host_ws/$target_service/yacd ]]; then
        git clone --depth 1 https://github.com/haishanh/yacd.git
    fi

    if [[ -d $host_ws/$target_service/yacd && ! -d $host_ws/$target_service/yacd/public ]]; then
        pushd $host_ws/$target_service/yacd 1>/dev/null 2>&1
        npm i -g pnpm && pnpm i && pnpm build
        popd 1>/dev/null 2>&1
    fi

    if [[ -n $IKUUU_URL ]]; then
        curl $IKUUU_URL -o $host_ws/$target_service/ikuuu.yaml && \
        cat $host_ws/$target_service/ikuuu.yaml | tail -n +7  >> $host_ws/$target_service/config.yaml && \
        rm $host_ws/$target_service/ikuuu.yaml
    else
        echo "Maybe you need setup IKUUU_URL"
    fi
    # 定制内容结束

    popd 1>/dev/null 2>&1

    echo
    color_msg y 'leave setup_clash'
}

function setup_jellyfin() {
    echo
    color_msg y 'enter setup_jellyfin'
    echo

    local target_service=jellyfin # 定制服务名

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    pushd $host_ws/$target_service 1>/dev/null 2>&1

    # 定制内容开始
    mkdir -p $host_ws/$target_service/config
    mkdir -p $host_ws/$target_service/cache
    mkdir -p $host_ws/$target_service/media/{film,music,book,photo,tv,mv,other}
    # 定制内容结束

    popd 1>/dev/null 2>&1

    echo
    color_msg y 'leave setup_jellyfin'
}

function setup_sourcegraph() {
    echo
    color_msg y 'enter setup_sourcegraph'
    echo

    local target_service=sourcegraph # 定制服务名

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    pushd $host_ws/$target_service 1>/dev/null 2>&1

    # 定制内容开始
    mkdir -p $host_ws/$target_service/config
    mkdir -p $host_ws/$target_service/data
    # 定制内容结束

    popd 1>/dev/null 2>&1

    echo
    color_msg y 'leave setup_sourcegraph'
}

function setup_resilio() {
    echo
    color_msg y 'enter setup_resilio'
    echo

    local target_service=resilio # 定制服务名

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    pushd $host_ws/$target_service 1>/dev/null 2>&1

    # 定制内容开始
    mkdir -p $host_ws/$target_service
    # 定制内容结束

    popd 1>/dev/null 2>&1

    echo
    color_msg y 'leave setup_resilio'
}

function setup_glitchtip() {
    echo
    color_msg y 'enter setup_glitchtip'
    echo

    local target_service=glitchtip # 定制服务名

    local enable=`yq e ".services.$target_service.enable" $root_ws/dats.yml`
    if (( 0 == $enable )); then
        echo "$target_service disabled"
        return
    fi

    pushd $host_ws/$target_service 1>/dev/null 2>&1

    # 定制内容开始
    mkdir -p $host_ws/$target_service/pg_data
    mkdir -p $host_ws/$target_service/uploads
    local secret_key=`openssl rand -hex 32`
    sed -i "s#{{secret_key}}#$secret_key#" $host_ws/$service/docker-compose.yml
    # 定制内容结束

    popd 1>/dev/null 2>&1

    echo
    color_msg y 'leave setup_glitchtip'
}

function services_setup() {
    local target_service=${1:-''}

    color_msg y 'enter services_setup'
    echo

    local guest_dns_ip=`get_guest_dns_ip`

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        if [[ -n $target_service && $target_service != $service ]]; then
            continue
        fi

        echo

        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`

        if (( 0 == $enable )); then
            color_msg r "$service disabled"
            continue
        fi

        if [[ ! -d $root_ws/$service ]]; then
            color_msg r "$service do not exist"
            continue
        fi

        mkdir -p $host_ws/$service

        cp -vR $root_ws/$service/. $host_ws/$service/

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
        glitchtip)
            ;;
        *)
            ;;
        esac
    done


    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        if [[ -n $target_service && $target_service != $service ]]; then
            continue
        fi

        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`

        if (( 0 == $enable )); then
            continue
        fi

        if [[ ! -d $root_ws/$service ]]; then
            continue
        fi

        case $service in
        coredns)
            ;;
        nginx)
            setup_nginx
            ;;
        gitea)
            ;;
        drone)
            ;;
        clash)
            setup_clash
            ;;
        u3dacc)
            ;;
        jellyfin)
            setup_jellyfin
            ;;
        sourcegraph)
            setup_sourcegraph
            ;;
        resilio)
            setup_resilio
            ;;
        glitchtip)
            setup_glitchtip
            ;;
        *)
            ;;
        esac
    done
    
    echo
    color_msg y 'leave services_setup'
}

function services_start() {
    local target_service=${1:-''}

    color_msg y 'enter services_start'
    echo

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        if [[ -n $target_service && $target_service != $service ]]; then
            continue
        fi

        echo

        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`
        local start=`yq e ".services.$service.start" $root_ws/dats.yml`

        if (( 0 == $enable || 0 == $start )); then
            color_msg r "$service disabled or distart"
            continue
        fi

        if [[ ! -d $host_ws/$service ]]; then
            color_msg r "$service do not exist"
            continue
        fi

        pushd $host_ws/$service 1>/dev/null 2>&1

        is_service_running $service
        if (( 0 == $? )); then
            docker-compose up -d
        fi

        popd 1>/dev/null 2>&1
    done

    echo
    color_msg y 'leave services_start'
}

function services_stop() {
    local target_service=${1:-''}

    color_msg y 'enter services_stop'
    echo

    yq e '.services.*.name' $root_ws/dats.yml | while read -r service; do
        if [[ -n $target_service && $target_service != $service ]]; then
            continue
        fi

        echo

        local enable=`yq e ".services.$service.enable" $root_ws/dats.yml`
        local start=`yq e ".services.$service.start" $root_ws/dats.yml`

        if (( 0 == $enable || 0 == $start )); then
            color_msg r "$service disabled or distart"
            continue
        fi

        if [[ ! -d $host_ws/$service ]]; then
            color_msg r "$service do not exist"
            continue
        fi

        pushd $host_ws/$service 1>/dev/null 2>&1

        is_service_running $service
        if (( 1 == $? )); then
            docker-compose down
        fi

        popd 1>/dev/null 2>&1
    done

    echo
    color_msg y 'leave services_stop'
}

function services_restart() {
    local target_service=`select_service`
    services_stop $target_service && \
    services_setup $target_service && \
    services_start $target_service
}

$exec_cmd
