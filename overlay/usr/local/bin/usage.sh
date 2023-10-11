#!/bin/sh

echo
date

echo
cat /etc/os-release

echo
echo SECRET_KEY=$SECRET_KEY

ip route

echo
ping -c 4 "$(ip route | awk '/default/ {print $3}')"

echo
ping -c 4 "$(head -1 /etc/resolv.conf | awk '{print $2}')"
ping -c 4 -M "do" -s 1472 8.8.8.8

set -x
# tcpdump -i eth0 -nnv &

# netcat -vz www.google.com 443

# openssl s_client -connect www.google.com:443 -servername www.google.com -debug -msg

curl -L -v https://raw.githubusercontent.com/dylanaraps/neofetch/7.1.0/neofetch

curl -v -A "Mozilla/5.0" https://www.google.com/

curl -v https://letsencrypt.org/
curl -v https://www.mozilla.org/
curl -v https://www.cloudflare.com/

echo
curl http://artscene.textfiles.com/asciiart/unicorn


# echo
# openssl s_client -connect github.com:80
# openssl s_client -connect github.com:443

echo
curl -L -v https://raw.githubusercontent.com/dylanaraps/neofetch/7.1.0/neofetch

echo
echo "At least one COMMAND instruction is required. See the project README for usage."

sleep infinity
