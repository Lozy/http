#SQUID CONFIG: DEBIAN
SoftRelease="SquidAuto 1.0.0"
AuthorIpRange="199.91.71.193/32"
#PORT=$(( RANDOM % ( 65534-1024 ) + 1024 ))
PORT=2012

function authorIps(){
   echo "AuthotIpRange: "$(cat /etc/squid3/squid.conf | sed -n 's/\<acl mymaster src \(.*\)/\1/p')
   [ -z "$1" ] && read -p "Adding New IpRange:" newiprange 
   [ -n "$1" ] && newiprange=$1

   [ -n "$newiprange" ] && ( sed -i "s/\<acl mymaster src.*/acl mymaster src ${newiprange} /g" /etc/squid3/squid.conf ) && \
     echo "Update AuthotIpRange: "$(cat /etc/squid3/squid.conf | sed -n 's/\<acl mymaster src \(.*\)/\1/p')
}

function adduser(){
  user=$(echo $1 | cut -d "@" -f 1 )
  pwd=$(echo $1 | cut -d "@" -f 2 )

  [ -z "$user" ] && return 0
  $(find / -name htpasswd | head -1 ) -b /etc/squid3/passwd  ${user} ${pwd}
}

function deluser(){
  [ -z "${1}" ] && return 0
  $(find / -name htpasswd | head -1 ) -D /etc/squid3/passwd  ${1}
}
function addip(){
  [ -z "${1}" ] && return 0
  ipname="ip-add"$( echo ${1} | sed 's/.*\.\(.*\)/\1/g' )
       cat >>/etc/squid3/squid.conf<<EOF
acl ${ipname} myip ${1}
tcp_outgoing_address ${1} ${ipname}

EOF
}
function delip(){   
  [ -z "${1}" ] && return 0
  sed -i '/'${1}'/d' /etc/squid3/squid.conf 
}

function install(){
   apt-get update
   apt-get install squid3 apache2-utils -y
   /etc/init.d/squid3 stop

   mkdir -p /var/squid3/cache
   useradd squid3 -s /bin/false
   chown squid3:squid3 /var/squid3/cache/ -R
   chown squid3:squid3 /var/log/squid3/ -R

   cat >/etc/squid3/squid.conf <<EOF
http_port ${PORT}
dns_nameservers 8.8.8.8
cache_access_log /var/log/squid3/access.log
cache_log /var/log/squid3/cache.log

cache_effective_user squid3
cache_effective_group squid3

cache_mem 5 MB
cache_dir ufs /var/squid3/cache 4096 16 256
cache_store_log /var/log/squid3/store.log
#visible_hostname
#cache_mgr

acl ip_allow src all
acl mymaster src ${AuthorIpRange}
http_access allow mymaster

auth_param basic program /usr/lib/squid3/ncsa_auth  /etc/squid3/passwd
acl passwder proxy_auth REQUIRED
http_access allow passwder
http_access deny all

forwarded_for delete
via Deny all
EOF

   ip_num=$(ifconfig | grep 'inet addr' | grep -Ev 'inet addr:127.0.0|inet addr:192.168.0|inet addr:10.0.0' | sed -n 's/.*inet addr:\([^ ]*\) .*/\1/p' | wc -l)
   ips=$(ifconfig | grep 'inet addr' | grep -Ev 'inet addr:127.0.0|inet addr:192.168.0|inet addr:10.0.0' | sed -n 's/.*inet addr:\([^ ]*\) .*/\1/p')

   genall=""

   [ $ip_num -gt 1 ] && ( echo $ips | sed 's/ /\n/g' ) && read -p "Server IP > 1, Adding all IP as HTTP Proxy Server ?(yes|no)" genall

   if [ "$genall" == "yes" ] || [ "$genall" == "Yes" ] || [ "$genall" == "YES" ];then

    for((i=1;i<=ip_num;i++));do
     ip=$( echo $ips | sed 's/ /\n/g' | sed -n ${i}p )
     ipname="ip"$i$( echo $ip | sed 's/.*\.\(.*\)/\1/g' )
   
     cat >>/etc/squid3/squid.conf<<EOF
acl ${ipname} myip ${ip}
tcp_outgoing_address ${ip} ${ipname}

EOF
   done

   elif [ "$genall" == "" ] || [ "$genall" == "No" ] || [ "$genall" == "no" ] || [ "$genall" == "NO" ];then
    ip=$(echo $ips | sed 's/ /\n/g'|sed -n 1p)
    ipname="ipm"$( echo $ip | sed 's/.*\.\(.*\)/\1/g' )
    echo "Setting Proxy as ${ip}:${PORT} You can Modify/Add it latter."
   
    cat >>/etc/squid3/squid.conf<<EOF
acl ${ipname} myip ${ip}
tcp_outgoing_address ${ip} ${ipname}

EOF

  else
    echo "INPUT ERROR!" && exit
  fi

  echo "Setting Default user and password |  squid:squid"
  /usr/bin/htpasswd -c -b /etc/squid3/passwd squid squid

  squid3 -k parse
  /etc/init.d/squid3 start
  clear
  cat <<EOF
+-----------------------------------------+
Squid3 HTTP Config Done. 
+-----------------------------------------+
Config Version:         ${SoftRelease}
Proxy Port:             ${PORT}
AuthorIpRange:          ${AuthorIpRange}
User:                   squid@squid
+_________________________________________+
EOF
}

while getopts "ia:d:p:q:m:v" arg
do
        case $arg in
              "i")
                  install
                ;;
              "a")
                  adduser $OPTARG
                  exit
                ;;
              "d")
                  deluser $OPTARG
                  exit
                ;;
              "p")
                  delip ${OPTARG}
                  addip ${OPTARG}
                  exit
                ;;
              "q")
                  delip ${OPTARG}
                  exit
                ;;              
              "m")
                  authorIps "${OPTARG}"
                  exit
                ;;
              "v")
                  echo $SoftRelease
                  exit
                ;;
              "?")  
                  echo "USAGE: ./squidauto [ -i instal | -a add user@password | -d delete user | -p add ip | -q delete ip]"
                  exit
               ;;
        esac
done
