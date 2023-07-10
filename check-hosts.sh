#!/bin/bash

declare -A NODES

CONFIG_FILE=config

install_ssh_pass(){
    if [[ -z "$(command -v sshpass)" ]]; then
        echo "sshpass not found"
        sudo apt-get install sshpass
    fi
}

ssh_connection_str(){
    sshpass -p "${NODES[$i, pass]}" ssh "${NODES[$i, login]}"@"${NODES[$i, ip]}" -p "${NODES[$i, port]}" -no StrictHostKeyChecking=no "$1"
}

get_sys_info(){
    #get hostname
    echo "===============${NODES[$i, ip]}================="
    ssh_connection_str "echo -n 'Hostname: '; hostname"
    #get os type
    ssh_connection_str "echo -n 'OS Type: '; cat /etc/os-release | grep PRETTY_NAME | cut -d '\"' -f 2"
    #get kernel version
    ssh_connection_str "echo -n 'Kernel: '; uname -r"
    #get cpu cores
    ssh_connection_str "echo -n 'CPU Cores: '; nproc"
    #get cpu frequency
    ssh_connection_str "echo -n 'CPU Frequency:'; grep MH /proc/cpuinfo | uniq | cut -d ':' -f 2;"
    #get ram
    ssh_connection_str "free -h | grep Mem" | awk '{print "RAM: " $2}'
    #get swap
    ssh_connection_str "free -h | grep Swap" | awk '{print "Swap: " $2}'
    #get hdd
    ssh_connection_str "df -H / | tail -1" | awk '{print "HDD: " $2}'
    #get network connect
    ssh_connection_str "ping -c 1 8.8.8.8 > /dev/null && echo 'Network: Ok' || echo 'Network: Not';"
    #TODO: get iptables rules
    #sshpass -p "$pass" ssh "$login"@"$ip" -p $port -no StrictHostKeyChecking=no "echo $pass | sudo -S iptables -L -vn"
    echo "=============================================="
}

check_ssh_connection(){
    for (( j=0; j<$(awk 'NF > 0' $CONFIG_FILE | wc -l); j++ )); do
        ssh_connection_str "echo quit | telnet ${NODES[$j, ip]} ${NODES[$j, port]} 2>/dev/null | grep Connected || echo 'Not connected (${NODES[$j, ip]})'"
    done
}

read_config(){
    i=0
    while read -r line
    do 
        NODES["$i", ip]+=$(echo "$line" | cut -d ":" -f 2)
        NODES["$i", login]+=$(echo "$line" | cut -d ":" -f 1)
        NODES["$i", port]+=$(echo "$line" | cut -d ":" -f 3)
        NODES["$i", pass]+=$(echo "$line" | cut -d ":" -f 4)
        ((i++))
    done < <(awk 'NF > 0' $CONFIG_FILE)
}

run_checker(){
    for (( i=0; i<$(awk 'NF > 0' $CONFIG_FILE | wc -l); i++ )); do
      get_sys_info "$i";
      check_ssh_connection "$i";
    done
}

main(){
    install_ssh_pass;
    read_config;
    run_checker;
}

main;