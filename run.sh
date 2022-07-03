#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
set -e

# Powered by Gee.Labs - 极数实验室
# Discord : https://discord.gg/za8gAUGdpT
# 本工具开源发布，欢迎大家二次修改使用
# 使用中如遇任何问题，请加入Discord官方群组，联系技术人员排查问题

if [[ "$(cat /etc/os-release | grep "^VERSION_ID" | awk -F '"' '{print $2}')" != "20.04" ]]; then
	echo "Error: You must be ubuntu 20.04 system to run this script !"
	exit 1
elif [ $(id -u) != "0" ]; then
	echo "Error: You must be root to run this script !"
	exit 1
fi

###############################################################################################

# user config
CONFIG_APTOS_WORKSPACE='/aptos'
CONFIG_APTOS_NODENAME='geelabs'

# tools config
CONFIG_ROOT_DIR=$(cd $(dirname $0); pwd)
CONFIG_CORE_DIR=$CONFIG_ROOT_DIR/core
CONFIG_APTOS_WORKSPACE=$CONFIG_APTOS_WORKSPACE/run

# system info
Public_IP=`curl -s cip.cc | grep "^IP" | awk '{print $3}'`
rm -rf $CONFIG_APTOS_WORKSPACE && mkdir -p $CONFIG_APTOS_WORKSPACE && cd $CONFIG_APTOS_WORKSPACE

###############################################################################################

Show_Banner(){
	if ! type toilet >/dev/null 2>&1; then
		apt update >/dev/null 2>&1
		apt install toilet -y >/dev/null 2>&1
	fi
	if ! type jq >/dev/null 2>&1; then
		apt install jq -y >/dev/null 2>&1
	fi
	clear && clear
	toilet -f ascii12 -F metal Aptos-AIT2 -t
	echo "    Tools : Aptos AIT-2 Tools"
	echo "  Version : v1.0"
	echo "  Powered : Gee.Labs"
	echo "  Discord : https://discord.gg/za8gAUGdpT"
	echo
	echo "###########################################"
	echo
}

Show_System_Info(){
	echo "    AIT2 node : $CONFIG_APTOS_NODENAME"
	echo "    Public IP : $Public_IP"
	echo "          CPU : $(cat /proc/cpuinfo | grep "^model name" | sort | uniq | head -1 | awk -F ':' '{print $2}' | sed 's/^\s*//')"
	echo "        Cores : $(cat /proc/cpuinfo | grep "^core id" | sort | uniq | wc -l)"
	echo "   Processors : $(cat /proc/cpuinfo | grep "^processor" | wc -l)"
	echo "       Memory : $(free -h | grep "^Mem:" | awk '{print $2}' | sed 's/i//')"
	echo -e "\n###########################################\n"
}

Install_Docker(){
	echo -e " Init system starting...\n"
	echo -e "[1/11] Install docker client : \c"
	if ! type docker >/dev/null 2>&1; then
		bash <(curl https://get.docker.com/) >/dev/null 2>&1
	fi
	echo -e "\033[32m$(docker -v | sed 's/Docker version //')\033[0m"
}

Install_Docker_Compose(){
	echo -e "[2/11] Install docker-compose : \c"
	if ! type docker-compose >/dev/null 2>&1; then
		cp $CONFIG_CORE_DIR/docker-compose /usr/bin/docker-compose
	fi
	echo -e "\033[32m$(docker-compose -v | awk '{print $NF}')\033[0m"
}

Install_Aptos_Cli(){
	echo -e "[3/11] Install aptos cli client : \c"
	if ! type aptos >/dev/null 2>&1; then
		cp $CONFIG_CORE_DIR/aptos /usr/bin/aptos
	fi
	echo -e "\033[32m$(aptos --version | awk '{print $2}')\033[0m"
}

Download_Docker_Config(){
	echo -e "[4/11] Download docker files : \c"
	cp $CONFIG_CORE_DIR/docker-compose.yaml $CONFIG_APTOS_WORKSPACE
	cp $CONFIG_CORE_DIR/validator.yaml $CONFIG_APTOS_WORKSPACE
	echo -e "\033[32m$CONFIG_APTOS_WORKSPACE/docker-compose.yaml $CONFIG_APTOS_WORKSPACE/validator.yaml\033[0m"
}

Generate_Key_Pairs(){
	echo -e "[5/11] Generate key pairs : \c"
	local Aptos_Keys_Json=$(aptos genesis generate-keys --output-dir $CONFIG_APTOS_WORKSPACE)
	echo -e "\033[32m$(echo $Aptos_Keys_Json | jq -r .Result[] | xargs)\033[0m"
}

Set_Validator_Config(){
	echo -e "[6/11] Set validator config : \c"
	local Aptos_Validator_Json=$(aptos genesis set-validator-configuration --keys-dir $CONFIG_APTOS_WORKSPACE --local-repository-dir $CONFIG_APTOS_WORKSPACE --username $CONFIG_APTOS_NODENAME --validator-host ${Public_IP}:6180 --full-node-host ${Public_IP}:6182)
	echo -e "\033[32m$(echo $Aptos_Validator_Json | jq -r .Result)\033[0m"
}

Create_Layout_Yaml(){
	echo -e "[7/11] Create layout yaml : \c"
	cat > $CONFIG_APTOS_WORKSPACE/layout.yaml << EOF
---
root_key: "F22409A93D1CD12D2FC92B5F8EB84CDCD24C348E32B3E7A720F3D2E288E63394"
users:
  - "$CONFIG_APTOS_NODENAME"
chain_id: 40
min_stake: 0
max_stake: 100000
min_lockup_duration_secs: 0
max_lockup_duration_secs: 2592000
epoch_duration_secs: 86400
initial_lockup_timestamp: 1656615600
min_price_per_gas_unit: 1
allow_new_validators: true
EOF
	echo -e "\033[32m$CONFIG_APTOS_WORKSPACE/layout.yaml\033[0m"
}

Download_AptosFramework_Move(){
	echo -e "[8/11] Download framework move : \c"
	cp -r $CONFIG_CORE_DIR/framework $CONFIG_APTOS_WORKSPACE
	echo -e "\033[32mSuccess\033[0m"
}

Compile_GenesisBlob_Waypoint(){
	echo -e "[9/11] Compile genesisblob/waypoint : \c"
	echo -e "\033[32m$(aptos genesis generate-genesis --local-repository-dir $CONFIG_APTOS_WORKSPACE --output-dir $CONFIG_APTOS_WORKSPACE | jq -r .Result[] | xargs)\033[0m"
}

Show_Running_Dir(){
	echo -e "[10/11] Show running dir : \c"
	echo -e "\033[32m$CONFIG_APTOS_WORKSPACE\033[0m"
}

Run_Docker(){
	echo -e "[11/11] Start validator docker : \c"
	local Docker_Name=$(docker ps | grep "run-validator" | awk '{print $NF}')
	if [[ -n "$Docker_Name" ]]; then
		docker stop $Docker_Name >/dev/null 2>&1
		docker rm $Docker_Name >/dev/null 2>&1
	fi
	docker-compose up -d >/dev/null 2>&1
	echo -e "\033[32m$(docker ps | grep "run-validator" | awk '{print $NF}')\033[0m"
}

Show_Running_Info(){
	echo -e "\n\033[32mThe aptos AIT-2 validator node is running successfully !\033[0m\n"
	echo -e "###########################################\n"
	echo -e "    Aptos AIT-2 validator node info : \n"
	echo "          [Public Keys]"
	echo -e "         Consensus Key : \033[32m$(cat $CONFIG_APTOS_WORKSPACE/$CONFIG_APTOS_NODENAME.yaml | grep "^consensus_public_key" | awk -F '"' '{print $2}')\033[0m"
	echo -e "           Account Key : \033[32m$(cat $CONFIG_APTOS_WORKSPACE/$CONFIG_APTOS_NODENAME.yaml | grep "^account_public_key" | awk -F '"' '{print $2}')\033[0m"
	echo -e " Validator Network Key : \033[32m$(cat $CONFIG_APTOS_WORKSPACE/$CONFIG_APTOS_NODENAME.yaml | grep "^validator_network_public_key" | awk -F '"' '{print $2}')\033[0m"

	echo "       [Validator Node]"
	echo -e "            IP Address : \033[32m$Public_IP\033[0m\n"
}

###############################################################################################

Show_Banner
Show_System_Info
Install_Docker
Install_Docker_Compose
Install_Aptos_Cli
Download_Docker_Config
Generate_Key_Pairs
Set_Validator_Config
Create_Layout_Yaml
Download_AptosFramework_Move
Compile_GenesisBlob_Waypoint
Show_Running_Dir
Run_Docker
Show_Running_Info


exit