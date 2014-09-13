#!/bin/sh

PWD=`pwd`

src_home=$PWD/../
dst_home=$HOME/local/fooyun
method="rsync"

while getopts s:d:m: ac
do
    case $ac in
    s) src_home=$OPTARG
        ;;
    d) dst_home=$OPTARG
        ;;
    m) method=$OPTARG
        ;;
    \?) echo "invalid args"
        exit 1
        ;;
    esac
done

mkdir -p $dst_home && cd $dst_home
[ $? != 0 ] && exit 1

cat <<EOF >$PWD/exclude.list
*.svn*
*.swp*
EOF

if [ $method = "init" ]; then
    sql_dir=fooyun-web-beta/db
    for db_conf in "fooyun-web-beta/conf/application.conf" "fooyun-web-beta_cls/conf/application.conf"
    do
        db_name=`awk -F '[/?]' '/^db.url/{print $4}' $db_conf`
        db_host=`awk -F '[/:]' '/^db.url/{print $5}' $db_conf`
        db_port=`awk -F '[/:]' '/^db.url/{print $6}' $db_conf`
        db_user=`awk -F '[=]' '/^db.user/{print $2}' $db_conf`
        db_pass=`awk -F '[=]' '/^db.pass/{print $2}' $db_conf`

        mysql -h$db_host -P$db_port -u$db_user -p$db_pass -e "drop database $db_name; create database $db_name;"
        mysql -h$db_host -P$db_port -u$db_user -p$db_pass $db_name < $sql_dir/fooyun.sql
        mysql -h$db_host -P$db_port -u$db_user -p$db_pass $db_name < $sql_dir/init.sql
    done
fi

if [ $method = "rsync" ]; then
    rsync -av --exclude-from=$PWD/exclude.list $src_home/web/ fooyun-web-beta/
    rsync -av --exclude-from=$PWD/exclude.list $src_home/web/ fooyun-web-beta_cls/
    rsync -av --exclude-from=$PWD/exclude.list $src_home/mngrserver/ fooyun-mngrserver-beta_x86_64/

    rsync -av $src_home/dist/fooyun-dataserver-beta_x86_64.tar.gz fooyun-web-beta_cls/public/deploy/fooyun-dataserver-beta_x86_64.tar.gz
    rsync -av $src_home/dist/fooyun-proxy-beta_x86_64.tar.gz fooyun-web-beta_cls/public/deploy/fooyun-proxy-beta_x86_64.tar.gz

    #########################
    #Configurations
    #########################
    cnf_custom=(myconf/application.conf  myconf/application.conf_cls  myconf/fooyun_mngr.ini  myconf/foo_conf.lua  myconf/mngr_config.lua)
    cnf_orig=(fooyun-web-beta/conf/application.conf  fooyun-web-beta_cls/conf/application.conf  \
        fooyun-mngrserver-beta_x86_64/bin/fooyun_mngr.ini  fooyun-mngrserver-beta_x86_64/script/foo_conf.lua  \
        fooyun-mngrserver-beta_x86_64/script/mngr/mngr_config.lua)

    for((i=0;i<${#cnf_custom[@]};i++))
    do
        if [ -e ${cnf_custom[$i]} ]; then
            rsync -av ${cnf_custom[$i]} ${cnf_orig[$i]}
            [ $? != 0 ] && exit 1
        else
            mkdir -p `dirname ${cnf_custom[$i]}`
            rsync -av ${cnf_orig[$i]} ${cnf_custom[$i]}
            [ $? != 0 ] && exit 1
        fi
    done
fi

rm $PWD/exclude.list
