#!/bin/bash
set -e

if [ "$*" == "gencert" ]; then

  /gencert.sh
  exit 0

fi

if [ ! -f /opt/vpn_server.config ]; then

  : ${PSK:='notasecret'}
  : ${USERNAME:=user$(cat /dev/urandom | tr -dc '0-9' | fold -w 4 | head -n 1)}

  printf '# '
  printf '=%.0s' {1..24}
  echo
  echo \# ${USERNAME}

  if [[ $PASSWORD ]]
  then
    echo '# <use the password specified at -e PASSWORD>'
  else
    PASSWORD=$(cat /dev/urandom | tr -dc '0-9' | fold -w 20 | head -n 1 | sed 's/.\{4\}/&./g;s/.$//;')
    echo \# ${PASSWORD}
  fi

  printf '# '
  printf '=%.0s' {1..24}
  echo

  /opt/vpnserver start 2>&1 > /dev/null

  # while-loop to wait until server comes up
  # switch cipher
  while : ; do
    set +e
    /opt/vpncmd localhost /SERVER /CSV /CMD ServerCipherSet DHE-RSA-AES256-SHA 2>&1 > /dev/null
    [[ $? -eq 0 ]] && break
    set -e
    sleep 1
  done

  # enable L2TP_IPsec
  /opt/vpncmd localhost /SERVER /CSV /CMD IPsecEnable /L2TP:yes /L2TPRAW:yes /ETHERIP:no /PSK:${PSK} /DEFAULTHUB:DEFAULT

  # enable SecureNAT
  /opt/vpncmd localhost /SERVER /CSV /HUB:DEFAULT /CMD SecureNatEnable

  # enable OpenVPN
  /opt/vpncmd localhost /SERVER /CSV /CMD OpenVpnEnable yes /PORTS:1194

  if [[ "*${CERT}*" != "**" && "*${KEY}*" != "**" ]]; then
    # server cert/key pair specified via -e
    CERT=$(echo ${CERT} | sed -r 's/\-{5}[^\-]+\-{5}//g;s/[^A-Za-z0-9\+\/\=]//g;')
    echo -----BEGIN CERTIFICATE----- > server.crt
    echo ${CERT} | fold -w 64 >> server.crt
    echo -----END CERTIFICATE----- >> server.crt

    KEY=$(echo ${KEY} | sed -r 's/\-{5}[^\-]+\-{5}//g;s/[^A-Za-z0-9\+\/\=]//g;')
    echo -----BEGIN PRIVATE KEY----- > server.key
    echo ${KEY} | fold -w 64 >> server.key
    echo -----END PRIVATE KEY----- >> server.key

    /opt/vpncmd localhost /SERVER /CSV /CMD ServerCertSet /LOADCERT:server.crt /LOADKEY:server.key
    rm server.crt server.key
    export KEY='**'
  fi

  /opt/vpncmd localhost /SERVER /CSV /CMD OpenVpnMakeConfig openvpn.zip 2>&1 > /dev/null

  # extract .ovpn config
  unzip -p openvpn.zip *_l3.ovpn > softether.ovpn
  # delete "#" comments, \r, and empty lines
  sed -i '/^#/d;s/\r//;/^$/d' softether.ovpn
  # send to stdout
  cat softether.ovpn

  # disable extra logs
  /opt/vpncmd localhost /SERVER /CSV /HUB:DEFAULT /CMD LogDisable packet
  /opt/vpncmd localhost /SERVER /CSV /HUB:DEFAULT /CMD LogDisable security

  # add user
  /opt/vpncmd localhost /SERVER /HUB:DEFAULT /CSV /CMD UserCreate ${USERNAME} /GROUP:none /REALNAME:none /NOTE:none
  /opt/vpncmd localhost /SERVER /HUB:DEFAULT /CSV /CMD UserPasswordSet ${USERNAME} /PASSWORD:${PASSWORD}

  export PASSWORD='**'

  # set password for hub
  HPW=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 16 | head -n 1)
  /opt/vpncmd localhost /SERVER /HUB:DEFAULT /CSV /CMD SetHubPassword ${HPW}

  # set password for server
  SPW=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 20 | head -n 1)
  /opt/vpncmd localhost /SERVER /CSV /CMD ServerPasswordSet ${SPW}

  /opt/vpnserver stop 2>&1 > /dev/null

  # while-loop to wait until server goes away
  set +e
  while pgrep vpnserver > /dev/null; do sleep 1; done
  set -e

  echo \# [initial setup OK]

fi

## openvpn shit

cat > /etc/openvpn/openvpn.conf <<-EOF
client
dev tun
proto udp
remote ${HIDE_SERVER}.hide.me 3478
cipher AES-128-CBC
resolv-retry infinite
nobind
persist-key
persist-tun
mute-replay-warnings
ca TrustedRoot.pem
verb 3
auth-user-pass userpass.txt
reneg-sec 0
EOF

echo \# [openvpn.conf OK]

cat > /etc/openvpn/TrustedRoot.pem <<-EOF
-----BEGIN CERTIFICATE-----
MIIDxTCCAq2gAwIBAgIQAqxcJmoLQJuPC3nyrkYldzANBgkqhkiG9w0BAQUFADBs
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSswKQYDVQQDEyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5j
ZSBFViBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTMxMTExMDAwMDAwMFowbDEL
MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
LmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2Ug
RVYgUm9vdCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMbM5XPm
+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRnogocsF9ppkCxxLeyj9CYpKlBWTrT3JTW
PNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG++MXs2ziS4wblCJEM
xChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EKmEFB
Ik5lYYeBQVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8VdteZOE3
hzBWBOURtCmAEvF5OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10aUAsg
EsxBu24LUTi4S8sCAwEAAaNjMGEwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQF
MAMBAf8wHQYDVR0OBBYEFLE+w2kD+L9HAdSYJhoIAu9jZCvDMB8GA1UdIwQYMBaA
FLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3DQEBBQUAA4IBAQAcGgaX3Nec
nzyIZgYIVyHbIUf4KmeqvxgydkAQV8GK83rZEWWONfqe/EW1ntlMMUu4kehDLI6z
eM7b41N5cdblIZQB2lWHmiRk9opmzN6cN82oNLFpmyPInngiK3BD41VHMWEZ71jF
hS9OMPagMRYjyOfiZRYzy78aG6A9+MpeizGLYAiJLQwGXFK3xPkKmNEVX58Svnw2
Yzi9RKR/5CYrCsSXaQ3pjOLAEFe4yHYSkVXySGnYvCoCWw9E1CAx2/S6cCZdkGCe
vEsXCS+0yx5DaMkHJ8HSXPfqIbloEpw8nL+e/IBcm2PN7EeqJSdnoDfzAIJ9VNep
+OkuE6N36B9K
-----END CERTIFICATE-----
EOF

echo \# [TrustedRoot.pem OK]

cat > /etc/openvpn/userpass.txt <<-EOF
${HIDE_USER}
${HIDE_PASS}
EOF

echo \# [userpass.txt OK]
echo \# [user: $HIDE_USER]
echo \# [pass: $HIDE_PASS]

/etc/init.d/openvpn restart && sleep 10

export eth0_ip=`ifconfig | grep -C 1 eth0 | grep "inet addr:" | grep -Eo "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | head -1`
echo "1 rt2" >> /etc/iproute2/rt_tables
ip route add default via 172.17.0.1 dev eth0 table rt2
ip rule add from $eth0_ip table rt2 priority 500
ip rule add to $eth0_ip table rt2 priority 500
echo \# [setting ip routing OK]

exec "$@"
