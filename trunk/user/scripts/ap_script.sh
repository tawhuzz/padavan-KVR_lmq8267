#!/bin/sh
#/etc/storage/ap_script.sh
#copyright by hiboy

# AP中继连接守护功能。【0】 Internet互联网断线后自动搜寻；【1】 当中继信号断开时启动自动搜寻。
apauto=0

# AP连接成功条件，【0】 连上AP即可，不检查是否联网；【1】 连上AP并连上Internet互联网。
apauto2=1

# 【0】 联网断线后自动搜寻，大于【10】时则每隔【N】秒搜寻(无线网络会瞬断一下)，直到连上最优先信号。
aptime="0"

# 如搜寻的AP不联网则列入黑名单/tmp/apblack.txt 功能 【0】关闭；【1】启动
# 控制台输入【echo "" > /tmp/apblack.txt】可以清空黑名单
apblack=0

# 自定义分隔符号，默认为【@】，注意:下面配置一同修改
fenge='@'

# 【自动切换中继信号】功能 填写配置参数启动
cat >/tmp/ap2g5g.txt <<-\EOF
# 中继AP配置填写说明：
# 各参数用【@】分割开，如果有多个信号可回车换行继续填写即可(从第一行的参数开始搜寻)【第一行的是最优先信号】
# 搜寻时无线网络会瞬断一下
# 参数说明：
# ①2.4Ghz或5Ghz："2"=【2.4Ghz】"5"=【5Ghz】
# ②无线AP工作模式："0"=【AP（桥接被禁用）】"1"=【WDS桥接（AP被禁用）】"2"=【WDS中继（网桥 + AP）】"3"=【AP-Client（AP被禁用）】"4"=【AP-Client + AP】
# ③无线AP-Client角色： "0"=【LAN bridge】"1"=【WAN (Wireless ISP)】
# ④中继AP 的 SSID："ASUS"
# ⑤中继AP 密码："1234567890"
# ⑥中继AP 的 MAC地址："20:76:90:20:B0:F0"【可以不填，不限大小写】
# 下面是信号填写例子：（删除前面的#可生效）
#2@4@1@ASUS@1234567890
#2@4@1@ASUS_中文@1234567890@34:bd:f9:1f:d2:b1
#2@4@1@ASUS3@1234567890@34:bd:f9:1f:d2:b0



EOF
cat /tmp/ap2g5g.txt | grep -v '^#'  | grep -v "^$" > /tmp/ap2g5g
killall sh_apauto.sh
if [ -s /tmp/ap2g5g ] ; then
cat >/tmp/sh_apauto.sh <<-\EOF
#!/bin/sh
    logger -t "【AP 中继】" "连接守护启动"
    while true; do
        if [ ! -f /tmp/apc.lock ] ; then
            if [[ $(cat /tmp/apauto.lock) == 1 ]] ; then
            #【1】 当中继信号断开时启动自动搜寻
                a2=`iwconfig apcli0 | awk -F'"' '/ESSID/ {print $2}'`
                a5=`iwconfig apclii0 | awk -F'"' '/ESSID/ {print $2}'`
                [ "$a2" = "" -a "$a5" = "" ] && ap=1 || ap=0
                if [ "$ap" = "1" ] ; then
                    logger -t "【AP 中继】" "连接中断，启动自动搜寻"
                    /etc/storage/sh_ezscript.sh 0 t &
                fi
            fi
            if [[ $(cat /tmp/apauto.lock) == 0 ]] ; then
            #【2】 Internet互联网断线后自动搜寻
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
                echo "Internet互联网断线后自动搜寻"
                    /etc/storage/sh_ezscript.sh 0 t &
                fi
            fi
        fi
        sleep 69
    done
EOF
    chmod 777 "/tmp/sh_apauto.sh"
    echo $apauto > /tmp/apauto.lock
    [ "$1" = "crontabs" ] && /tmp/sh_apauto.sh &
else
    echo "" > /tmp/apauto.lock
fi
