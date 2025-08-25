# GFW List
curl -sS https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt | \
    base64 -d | sort -u | sed '/^$\|@@/d'| sed 's#!.\+##; s#|##g; s#@##g; s#http:\/\/##; s#https:\/\/##;' | \
    sed '/apple\.com/d; /sina\.cn/d; /sina\.com\.cn/d; /baidu\.com/d; /qq\.com/d' | \
    sed '/^[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+$/d' | grep '^[0-9a-zA-Z\.-]\+$' | \
    grep '\.' | sed 's#^\.\+##' | sort -u > /tmp/temp_gfwlist1

curl -sS https://raw.githubusercontent.com/hq450/fancyss/master/rules/gfwlist.conf | \
    sed 's/ipset=\/\.//g; s/\/gfwlist//g; /^server/d' > /tmp/temp_gfwlist2

curl -sS https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/gfw.txt > /tmp/temp_gfwlist3

cat /tmp/temp_gfwlist1 /tmp/temp_gfwlist2 /tmp/temp_gfwlist3 script/cust_gfwdomain.conf | \
    sort -u | sed 's/^\.*//g' > /tmp/temp_gfwlist
cat /tmp/temp_gfwlist | sed -e '/^$/d' > /tmp/proxy-domain-list.conf
sed "s/^full://g;s/^regexp:.*$//g;s/^/nameserver \//g;s/$/\/oversea/g" -i /tmp/proxy-domain-list.conf
cat /tmp/proxy-domain-list.conf > devices/common/diy/package/base-files/files/etc/smartdns/domain-set/proxy-domain-list.conf

# Update address.conf
# curl -sS https://raw.githubusercontent.com/Cats-Team/AdRules/main/smart-dns.conf > devices/common/diy/package/base-files/files/etc/smartdns/address.conf
curl -sS https://www.cloudflare.com/ips-v4/ > devices/common/diy/package/base-files/files/etc/smartdns/cloudflare-ipv4.txt


# 引入配置 conf-file /etc/smartdns/anti-ad-smartdns.conf
# curl -sS https://anti-ad.net/anti-ad-for-smartdns.conf > devices/common/diy/package/base-files/files/etc//smartdns/conf.d/anti-ad-smartdns.conf

# 获取DNS的SPKI，并按指定格式写入spki文件
echo "spki_cloudflare: $(echo | openssl s_client -connect '1.0.0.1:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" > devices/common/diy/package/base-files/files/etc/smartdns/spki
# 获取 8.8.8.8 的 SPKI 并追加到文件（不覆盖原有内容）
echo "spki_google: $(echo | openssl s_client -connect '8.8.8.8:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> devices/common/diy/package/base-files/files/etc/smartdns/spki
# 获取 腾讯 DNSPod 的 SPKI 并追加到文件（不覆盖原有内容）
echo "spki_DNSPod: $(echo | openssl s_client -connect '120.53.53.53:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> devices/common/diy/package/base-files/files/etc/smartdns/spki
# 获取 SB公共DNS 的 SPKI 并追加到文件（不覆盖原有内容）
echo "spki_SB: $(echo | openssl s_client -connect '185.222.222.222:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> devices/common/diy/package/base-files/files/etc/smartdns/spki
# 获取 OpenDNS(Cisco) 的 SPKI 并追加到文件（不覆盖原有内容）
echo "spki_OpenDNS(Cisco): $(echo | openssl s_client -connect '208.67.222.222:853' 2> /dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64)" >> devices/common/diy/package/base-files/files/etc/smartdns/spki

# Update China IPV4 List
qqwry="$(curl -kLfsm 5 https://raw.githubusercontent.com/metowolf/iplist/master/data/special/china.txt)"
ipipnet="$(curl -kLfsm 5 https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt)"
clang="$(curl -kLfsm 5 https://ispip.clang.cn/all_cn.txt)"
iplist="$qqwry\n$ipipnet\n$clang"
echo -e "${iplist}" | sort | uniq |sed -e '/^$/d' -e 's/^/blacklist-ip /g' > devices/common/diy/package/base-files/files/etc/smartdns/blacklist-ip.conf

# Update China List
accelerated_domains="$(curl -kLfsm 5 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf)"
apple="$(curl -kLfsm 5 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/apple.china.conf)"
google="$(curl -kLfsm 5 https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/google.china.conf)"
domain_list="$accelerated_domains\n$apple\n$google"
echo -e "${domain_list}" | sort | uniq |sed -e 's/#.*//g' -e '/^$/d' -e 's/server=\///g' -e 's/\/114.114.114.114//g' | sort -u > /tmp/domains.china.smartdns.conf
sed "s/^full://g;s/^regexp:.*$//g;s/^/nameserver \//g;s/$/\/china/g" -i /tmp/domains.china.smartdns.conf
cat /tmp/domains.china.smartdns.conf > devices/common/diy/package/base-files/files/etc/smartdns/domain-set/domains.china.smartdns.conf

# 删除
sudo sed -i '/# ING Hosts Start/,/# ING Hosts End/d' devices/common/diy/package/base-files/files/etc/hosts
# 添加
curl -s -k -L https://ghfast.top/https://raw.githubusercontent.com/shidahuilang/hosts/main/hosts | sudo tee -a devices/common/diy/package/base-files/files/etc/hosts



