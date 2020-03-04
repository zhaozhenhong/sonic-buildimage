#!/usr/bin/env bash

mkdir -p /etc/frr

CONFIG_TYPE=`sonic-cfggen -d -v 'DEVICE_METADATA["localhost"]["docker_routing_config_mode"]'`

if [ -z "$CONFIG_TYPE" ] || [ "$CONFIG_TYPE" == "separated" ]; then
    sonic-cfggen -d -y /etc/sonic/constants.yml -t /usr/share/sonic/templates/bgpd.conf.j2 > /etc/frr/bgpd.conf
    sonic-cfggen -d -t /usr/share/sonic/templates/zebra.conf.j2 > /etc/frr/zebra.conf
    sonic-cfggen -d -t /usr/share/sonic/templates/staticd.conf.j2 > /etc/frr/staticd.conf
    echo "no service integrated-vtysh-config" > /etc/frr/vtysh.conf
    rm -f /etc/frr/frr.conf
elif [ "$CONFIG_TYPE" == "unified" ]; then
    sonic-cfggen -d -y /etc/sonic/constants.yml -t /usr/share/sonic/templates/frr.conf.j2 >/etc/frr/frr.conf
    echo "service integrated-vtysh-config" > /etc/frr/vtysh.conf
    rm -f /etc/frr/bgpd.conf /etc/frr/zebra.conf /etc/frr/staticd.conf
fi

chown -R frr:frr /etc/frr/

sonic-cfggen -d -t /usr/share/sonic/templates/isolate.j2 > /usr/sbin/bgp-isolate
chown root:root /usr/sbin/bgp-isolate
chmod 0755 /usr/sbin/bgp-isolate

sonic-cfggen -d -t /usr/share/sonic/templates/unisolate.j2 > /usr/sbin/bgp-unisolate
chown root:root /usr/sbin/bgp-unisolate
chmod 0755 /usr/sbin/bgp-unisolate

mkdir -p /var/sonic
echo "# Config files managed by sonic-config-engine" > /var/sonic/config_status

rm -f /var/run/rsyslogd.pid

supervisorctl start rsyslogd

# start eoiu pulling, only if configured so
HAS_EOIU_CONFIG=$(sonic-cfggen -d -v "1 if WARM_RESTART and WARM_RESTART.bgp.bgp_eoiu")
if [ "$HAS_EOIU_CONFIG" == "1" ]; then
    if [[ $(sonic-cfggen -d -v 'WARM_RESTART.bgp.bgp_eoiu') == 'true' ]]; then
        supervisorctl start bgp_eoiu_marker
    fi
fi

# Start Quagga processes
supervisorctl start zebra

secs=30
while ((secs-- > 0))
do
    zebra_ready=$(netstat -tulpn | grep LISTEN | grep zebra)
    [[ ! -z $zebra_ready ]] && break
    sleep 1
done

supervisorctl start staticd
supervisorctl start bgpd

if [ "$CONFIG_TYPE" == "unified" ]; then
    supervisorctl start vtysh_b
fi

supervisorctl start fpmsyncd

BGP_ASN=`sonic-cfggen -d -v 'DEVICE_METADATA["localhost"]["bgp_asn"]'`
if [ -z "$BGP_ASN" ]; then
    supervisorctl start bfdd
    supervisorctl start ospfd
    supervisorctl start pimd
    supervisorctl start bgpcfgd_db
else
    supervisorctl start bgpcfgd
fi
