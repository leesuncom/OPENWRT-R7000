#!/bin/bash

# Update DNS SPKI
echo "spki_cloudflare: $(echo | openssl s_client -connect '1.0.0.1:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" > /etc/smartdns/spki
# 8.8.8.8 SPKI 
echo "spki_google: $(echo | openssl s_client -connect '8.8.8.8:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> /etc/smartdns/spki
# DNSPod SPKI
echo "spki_DNSPod: $(echo | openssl s_client -connect '120.53.53.53:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> /etc/smartdns/spki
# SB DNS SPKI 
echo "spki_SB: $(echo | openssl s_client -connect '185.222.222.222:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> /etc/smartdns/spki
# OpenDNS(Cisco) SPKI
echo "spki_OpenDNS(Cisco): $(echo | openssl s_client -connect '208.67.222.222:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> /etc/smartdns/spki

# Update cloudflare-ipv4
curl -sS https://www.cloudflare.com/ips-v4/ > /etc/smartdns/cloudflare-ipv4.txt

# Update blacklist-ip
curl -sS https://ghfast.top/https://raw.githubusercontent.com/leesuncom/NetGearR7000/refs/heads/main/common/etc/smartdns/blacklist-ip.conf > /etc/smartdns/blacklist-ip.conf

# Update hosts
sudo sed -i '/# ING Hosts Start/,/# ING Hosts End/d' /etc/hosts
curl -s -k -L https://ghfast.top/https://raw.githubusercontent.com/shidahuilang/hosts/main/hosts | sudo tee -a /etc/hosts

# Update China IPV4 List
curl -sS https://ghfast.top/https://raw.githubusercontent.com/leesuncom/NetGearR7000/main/common/etc/smartdns/domain-set/domains.china.smartdns.conf -o /tmp/domains.china.smartdns.conf
cp /tmp/domains.china.smartdns.conf /etc/smartdns/domain-set/domains.china.smartdns.conf

# Update GFW List
curl -sS https://ghfast.top/https://raw.githubusercontent.com/leesuncom/NetGearR7000/main/common/etc/smartdns/domain-set/proxy-domain-list.conf -o /tmp/proxy-domain-list.conf
cp /tmp/proxy-domain-list.conf /etc/smartdns/domain-set/proxy-domain-list.conf

# Update address.conf
# curl -sS https://ghfast.top/https://raw.githubusercontent.com/Cats-Team/AdRules/main/smart-dns.conf -o /tmp/address.conf
# cp /tmp/address.conf /etc/smartdns/address.conf

# onf-file /etc/smartdns/anti-ad-smartdns.conf
# curl -sS https://anti-ad.net/anti-ad-for-smartdns.conf -o /tmp/anti-ad-smartdns.conf
# cp /tmp/anti-ad-smartdns.conf /etc/smartdns/conf.d/anti-ad-smartdns.conf


/etc/init.d/smartdns restart


