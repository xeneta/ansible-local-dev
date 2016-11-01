#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
HOSTS_FILE="$DIR/hosts"
ID_RSA_FILE="$DIR/id_rsa"
OVERRIDE_VARS_FILE="$DIR/vars.yml"
SITE_FILE="$DIR/../main.yml"
HOSTS=$(grep '\.ans\.local' $DIR/hosts | grep -v ';' | sort | uniq)
IP_PREFIX="192.168.200"
DOCKER_IMAGE_NAME="ansible_local_test"


cleanup_test_ips() {
	echo "Cleaning up ips and hosts of test containers..."
	grep -v "$IP_PREFIX" /etc/hosts | sudo tee /etc/hosts 1>/dev/null

	counter=1
	for host in $HOSTS
	do
		ip="$IP_PREFIX.$((counter++))"
		sudo ifconfig lo0 -alias "$ip" 2>/dev/null
	done
	echo "	Done."
}


setup_test_ips() {
	cleanup_test_ips

	echo "Setting up ips and hosts for test containers..."
	counter=1
	for host in $HOSTS
	do
		ip="$IP_PREFIX.$((counter++))"
		sudo ifconfig lo0 alias "$ip"
		echo "	$ip $host" | sudo tee -a /etc/hosts
	done
	echo "	Done."
}


build_image() {
	echo "Building test docker image..."
	cd $DIR && docker build -t "$DOCKER_IMAGE_NAME:latest" . 1>/dev/null
	echo "	Done."
}


start_containers() {
	echo "Starting test docker containers..."
	links=""
	counter=1

	for host in $HOSTS
	do
		docker rm -f "$host" &>/dev/null
	done

	for host in $HOSTS
	do
		ip="$IP_PREFIX.$((counter++))"
		docker run \
			-d \
			-p "$ip":22:22 \
			--name "$host" \
			-v /var/run/docker.sock:/var/run/docker.sock \
			"$DOCKER_IMAGE_NAME:latest" 1>/dev/null
	done
	echo "	Done."
}


run_ansible() {
	ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook \
		--inventory-file="$HOSTS_FILE" \
		--user=root \
		--private-key="$ID_RSA_FILE" \
		--inventory-file="$HOSTS_FILE" \
		--extra-vars="@$OVERRIDE_VARS_FILE" \
		"$SITE_FILE"
}


usage() {
	cat <<END

Usage: $0 [OPTIONS]

Run ansible towards docker containers.

Options:
   -f, --force	 : Recreate docker image and containers before running.
   -c, --cleanup : Remove aliases and hosts entries of containers after test.
   -h, --help	 : Show this help message.
END
}

# Parse args

force=false
cleanup=false

while [[ $# -gt 0 ]]
do
	key="$1"
	case $key in
		-cf|-fc)
			force=true
			cleanup=true
		;;
		-f|--force)
			force=true
		;;
		-c|--cleanup)
			cleanup=true
		;;
		*)
			usage
			exit 1
		;;
	esac
	shift
done


# Run!

if [ "$force" = true ]; then
	build_image
fi

setup_test_ips

if [ "$force" = true ]; then
	start_containers
fi

run_ansible

if [ "$cleanup" = true ]; then
	cleanup_test_ips
fi
