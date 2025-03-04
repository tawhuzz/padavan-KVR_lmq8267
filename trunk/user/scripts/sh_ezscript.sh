#!/bin/sh
#/etc/storage/inet_state_script.sh
### Custom user script
### Called on Internet status changed
### $1 - Internet status (0/1)
### $2 - elapsed time (s) from previous state
#copyright by hiboy
logger -t "【网络检测】" "互联网状态:$1, 经过时间:$2s."

# 【自动切换中继信号】功能 需要到【无线网络 - 无线桥接】页面配置



. /etc/storage/ap_script.sh

aptimes="$1"
if [ $((aptimes)) -gt "9" ] ; then
    logger -t "【连接 AP】" "$1秒后, 自动搜寻 ap"
    sleep $1
else
    logger -t "【连接 AP】" "10秒后, 自动搜寻 ap"
    sleep 10
fi
cat /tmp/ap2g5g.txt | grep -v '^#'  | grep -v "^$" > /tmp/ap2g5g
if [ ! -f /tmp/apc.lock ] && [ "$1" != "1" ] && [ -s /tmp/ap2g5g ] ; then
    touch /tmp/apc.lock
    a2="$(iwconfig apcli0 | awk -F'"' '/ESSID/ {print $2}')"
    a5="$(iwconfig apclii0 | awk -F'"' '/ESSID/ {print $2}')"
    [ "$a2" = "" -a "$a5" = "" ] && ap=1 || ap=0
    if [ "$ap" = "1" ] || [ "$2" = "t" ] && [ -f /tmp/apc.lock ] ; then
        #搜寻开始/tmp/ap2g5g
        while read line
        do
        c_line=`echo "$line" | grep -v '^#' | grep -v "^$"`
        if [ ! -z "$c_line" ] ; then
            apc="$line"
            radio=$(echo "$apc" | cut -d $fenge -f1)
            
            # ApCli 2.4Ghz
            if [ "$radio" = "2" ] ; then
                rtwlt_mode_x=`nvram get rt_mode_x`
            else
                rtwlt_mode_x=`nvram get wl_mode_x`
            fi
            # [ "$rtwlt_mode_x" = "3" ] || [ "$rtwlt_mode_x" = "4" ] &&
            
            rtwlt_mode_x="$(echo "$apc" | cut -d $fenge -f2)"
            rtwlt_sta_wisp="$(echo "$apc" | cut -d $fenge -f3)"
            rtwlt_sta_ssid="$(echo "$apc" | cut -d $fenge -f4)"
            rtwlt_sta_wpa_psk="$(echo "$apc" | cut -d $fenge -f5)"
            rtwlt_sta_bssid="$(echo "$apc" | cut -d $fenge -f6 | tr 'A-Z' 'a-z')"
            if [ "$radio" = "2" ] ; then
                ap="$(iwconfig | grep 'apcli0' | grep ESSID:"$rtwlt_sta_ssid" | wc -l)"
                if [ "$ap" = "0" ] ; then
                    ap="$(iwconfig |sed -n '/apcli0/,/Rate/{/apcli0/n;/Rate/b;p}' | grep $rtwlt_sta_bssid | tr 'A-Z' 'a-z' | wc -l)"
                fi
            else
                ap="$(iwconfig | grep 'apclii0' | grep ESSID:"$rtwlt_sta_ssid" | wc -l)"
                if [ "$ap" = "0" ] ; then
                    ap="$(iwconfig |sed -n '/apclii0/,/Rate/{/apclii0/n;/Rate/b;p}' | grep $rtwlt_sta_bssid | tr 'A-Z' 'a-z' | wc -l)"
                fi
            fi
            
            if [ "$ap" = "1" ] ; then
                logger -t "【连接 AP】" "当前是 $rtwlt_sta_ssid, 停止搜寻"
                rm -f /tmp/apc.lock
                if [ $((aptime)) -ge "9" ] ; then
                    /etc/storage/inet_state_script.sh $aptime "t" &
                    sleep 2
                    logger -t "【连接 AP】" "直到连上最优先信号 $(echo $(grep -v '^#' /tmp/ap2g5g | grep -v "^$" | head -1) | cut -d $fenge -f4)"
                fi
                exit
            else
                logger -t "【连接 AP】" "自动搜寻 $rtwlt_sta_ssid"
            fi
            if [ "$radio" = "2" ] ; then
            # ApCli 2.4Ghz
            iwpriv apcli0 set SiteSurvey=1
                if [ ! -z "$rtwlt_sta_bssid" ] ; then
                    logger -t "【连接 AP】" "自动搜寻 $rtwlt_sta_ssid:$rtwlt_sta_bssid"
                    site_survey="$(iwpriv apcli0 get_site_survey | sed -n "/$rtwlt_sta_bssid/p" | tr 'A-Z' 'a-z')"
                else
                    site_survey="$(iwpriv apcli0 get_site_survey | sed -n "/$rtwlt_sta_ssid/p" | tr 'A-Z' 'a-z')"
                fi
            else
                iwpriv apclii0 set SiteSurvey=1
                if [ ! -z "$rtwlt_sta_bssid" ] ; then
                    logger -t "【连接 AP】" "自动搜寻 $rtwlt_sta_ssid:$rtwlt_sta_bssid"
                    site_survey="$(iwpriv apclii0 get_site_survey | sed -n "/$rtwlt_sta_bssid/p" | tr 'A-Z' 'a-z')"
                else
                    site_survey="$(iwpriv apclii0 get_site_survey | sed -n "/$rtwlt_sta_ssid/p" | tr 'A-Z' 'a-z')"
                fi
            fi
            if [ -z "$site_survey" ] ; then
                logger -t "【连接 AP】" "没找到 $rtwlt_sta_ssid, 如果含中文请填写正确的MAC地址"
                ap3=1
            fi
            if [ ! -z "$site_survey" ] ; then
                Ch="${site_survey:0:4}"
                SSID="${site_survey:4:33}"
                BSSID="${site_survey:37:20}"
                Security="${site_survey:57:23}"
                Signal="${site_survey:80:9}"
                WMode="${site_survey:89:9}"
                ap3=0
            fi
            if [ "$apblack" = "1" ] ; then
                apblacktxt=$(grep "【SSID:$rtwlt_sta_bssid" /tmp/apblack.txt)
                if [ ! -z $apblacktxt ] ; then
                    logger -t "【连接 AP】" "当前是黑名单 $rtwlt_sta_ssid, 跳过黑名单继续搜寻"
                    ap3=1
                else
                    apblacktxt=$(grep "【SSID:$rtwlt_sta_ssid" /tmp/apblack.txt)
                    if [ ! -z $apblacktxt ] ; then
                        logger -t "【连接 AP】" "当前是黑名单 $rtwlt_sta_ssid, 跳过黑名单继续搜寻"
                        ap3=1
                    fi
                fi
            fi
            if [ "$ap3" != "1" ] ; then
                if [ "$radio" = "2" ] ; then
                    nvram set rt_channel=$Ch
                    iwpriv apcli0 set Channel=$Ch
                else
                    nvram set wl_channel=$Ch
                    iwpriv apclii0 set Channel=$Ch
                fi
                if [[ $(expr $Security : ".*none*") -gt "1" ]] ; then
                    rtwlt_sta_auth_mode="open"
                    rtwlt_sta_wpa_mode="0"
                fi
                if [[ $(expr $Security : ".*1psk*") -gt "1" ]] ; then
                    rtwlt_sta_auth_mode="psk"
                    rtwlt_sta_wpa_mode="1"
                fi
                if [[ $(expr $Security : ".*2psk*") -gt "1" ]] ; then
                    rtwlt_sta_auth_mode="psk"
                    rtwlt_sta_wpa_mode="2"
                fi
                if [[ $(expr $Security : ".*wpapsk*") -gt "1" ]] ; then
                    rtwlt_sta_auth_mode="psk"
                    rtwlt_sta_wpa_mode="1"
                fi
                if [[ $(expr $Security : ".*tkip*") -gt "1" ]] ; then
                    rtwlt_sta_crypto="tkip"
                fi
                if [[ $(expr $Security : ".*aes*") -gt "1" ]] ; then
                    rtwlt_sta_crypto="aes"
                fi
                if [ "$radio" = "2" ] ; then
                    nvram set rt_mode_x="$rtwlt_mode_x"
                    nvram set rt_sta_wisp="$rtwlt_sta_wisp"
                    nvram set rt_sta_ssid="$rtwlt_sta_ssid"
                    nvram set rt_sta_auth_mode="$rtwlt_sta_auth_mode"
                    nvram set rt_sta_wpa_mode="$rtwlt_sta_wpa_mode"
                    nvram set rt_sta_crypto="$rtwlt_sta_crypto"
                    nvram set rt_sta_wpa_psk="$rtwlt_sta_wpa_psk"
                    #强制20MHZ
                    nvram set rt_HT_BW=0
                else
                    nvram set wl_mode_x="$rtwlt_mode_x"
                    nvram set wl_sta_wisp="$rtwlt_sta_wisp"
                    nvram set wl_sta_ssid="$rtwlt_sta_ssid"
                    nvram set wl_sta_auth_mode="$rtwlt_sta_auth_mode"
                    nvram set wl_sta_wpa_mode="$rtwlt_sta_wpa_mode"
                    nvram set wl_sta_crypto="$rtwlt_sta_crypto"
                    nvram set wl_sta_wpa_psk="$rtwlt_sta_wpa_psk"
                fi
                logger -t "【连接 AP】" "$rtwlt_mode_x $rtwlt_sta_wisp $rtwlt_sta_ssid $rtwlt_sta_auth_mode $rtwlt_sta_wpa_mode $rtwlt_sta_crypto $rtwlt_sta_wpa_psk"
                nvram commit
                #restart_wan
                #sleep 10
                radio2_restart
                #sleep 4
                #if [ "$radio" = "2" ] ; then
                    #iwpriv apcli0 set ApCliEnable=0
                    #iwpriv apcli0 set ApCliAutoConnect=1
                #else
                    #iwpriv apclii0 set ApCliEnable=0
                    #iwpriv apclii0 set ApCliAutoConnect=1
                #fi
                sleep 15
                logger -t "【连接 AP】" "【Ch:$Ch】【SSID:$SSID】【BSSID:$BSSID】"
                logger -t "【连接 AP】" "【Security:$Security】【Signal(%):$Signal】【WMode:$WMode】"
                if [ "$radio" = "2" ] ; then
                    ap=`iwconfig | grep 'apcli0' | grep 'ESSID:""' | wc -l`
                else
                    ap=`iwconfig | grep 'apclii0' | grep 'ESSID:""' | wc -l`
                fi
                if [ "$ap" = "0" ] && [ "$apauto2" = "1" ] ; then
                    ping_text=`ping -4 223.5.5.5 -c 1 -w 4 -q`
                    ping_time=`echo $ping_text | awk -F '/' '{print $4}'| awk -F '.' '{print $1}'`
                    ping_loss=`echo $ping_text | awk -F ', ' '{print $3}' | awk '{print $1}'`
                    if [ ! -z "$ping_time" ] ; then
                        echo "ping：$ping_time ms 丢包率：$ping_loss"
                     else
                        echo "ping：失效"
                    fi
                    if [ ! -z "$ping_time" ] ; then
                        logger -t "【连接 AP】" "$ap 已连接上 $rtwlt_sta_ssid, 成功联网"
                        ap=0
                    else
                        ap=1
                        logger -t "【连接 AP】" "$ap 已连接上 $rtwlt_sta_ssid, 但未联网, 跳过继续搜寻"
                    fi
                fi
                if [ "$ap" = "1" ] ; then
                    logger -t "【连接 AP】" "$ap 无法连接 $rtwlt_sta_ssid"
                else
                    logger -t "【连接 AP】" "$ap 已连接上 $rtwlt_sta_ssid"
                    if [ "$apblack" = "1" ] ; then
                        ping_text=`ping -4 223.5.5.5 -c 1 -w 4 -q`
                        ping_time=`echo $ping_text | awk -F '/' '{print $4}'| awk -F '.' '{print $1}'`
                        ping_loss=`echo $ping_text | awk -F ', ' '{print $3}' | awk '{print $1}'`
                        if [ ! -z "$ping_time" ] ; then
                            echo "ping：$ping_time ms 丢包率：$ping_loss"
                         else
                            echo "ping：失效"
                        fi
                        if [ ! -z "$ping_time" ] ; then
                        echo "online"
                        else
                            apblacktxt="$ap AP不联网列入黑名单:【Ch:$Ch】【SSID:$SSID】【BSSID:$BSSID】【Security:$Security】【Signal(%):$Signal】【WMode:$WMode】"
                            logger -t "【连接 AP】" "$apblacktxt"
                            echo $apblacktxt >> /tmp/apblack.txt
                            rm -f /tmp/apc.lock
                            /etc/storage/inet_state_script.sh 0 "t" &
                            sleep 2
                            logger -t "【连接 AP】" "跳过黑名单继续搜寻, 直到连上最优先信号 $(echo $(grep -v '^#' /tmp/ap2g5g | grep -v "^$" | head -1) | cut -d $fenge -f4)"
                            exit
                        fi
                    fi
                    if [ "$rtwlt_sta_ssid" = $(echo $(grep -v '^#' /tmp/ap2g5g | grep -v "^$" | head -1) | cut -d $fenge -f4) ] ; then
                        logger -t "【连接 AP】" "当前是 $rtwlt_sta_ssid, 停止搜寻"
                        rm -f /tmp/apc.lock
                        logger -t "【连接 AP】" "当前连上最优先信号 $rtwlt_sta_ssid"
                        exit
                    else
                        rm -f /tmp/apc.lock
                        if [ $((aptime)) -ge "9" ] ; then
                            /etc/storage/inet_state_script.sh $aptime "t" &
                            sleep 2
                            logger -t "【连接 AP】" "直到连上最优先信号 $(echo $(grep -v '^#' /tmp/ap2g5g | grep -v "^$" | head -1) | cut -d $fenge -f4)"
                        fi
                        exit
                    fi
                fi
            fi
            sleep 5
        fi
        a2=`iwconfig apcli0 | awk -F'"' '/ESSID/ {print $2}'`
        a5=`iwconfig apclii0 | awk -F'"' '/ESSID/ {print $2}'`
        [ "$a2" = "" -a "$a5" = "" ] && ap=1 || ap=0
        sleep 2
        done < /tmp/ap2g5g
        sleep 60
        rm -f /tmp/apc.lock
        if [ "$ap" = "1" ] || [ "$2" = "t" ] && [ -f /tmp/apc.lock ] ; then
            #搜寻开始/tmp/ap2g5g
            /etc/storage/inet_state_script.sh 0 "t" &
            sleep 2
            logger -t "【连接 AP】" "继续搜寻"
            exit
        fi
        sleep 1
    fi
    rm -f /tmp/apc.lock
    sleep 1
fi
killall sh_apauto.sh
if [ -s /tmp/ap2g5g ] ; then
    /tmp/sh_apauto.sh &
else
    echo "" > /tmp/apauto.lock
fi
logger -t "【连接 AP】" "脚本完成"

