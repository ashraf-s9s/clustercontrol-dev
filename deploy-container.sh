#!/bin/bash

TBLC='cmon.containers'
TBLD='cmon.dockercontrol'
TBLJ='cmon.container_job'
SLEEP=30
SSH_OPTS='-oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -oNumberOfPasswordPrompts=0 -oConnectTimeout=10'
SCP_OPTS='-q -oUserKnownHostsFile=/dev/null -oStrictHostKeyChecking=no -oNumberOfPasswordPrompts=0 -oConnectTimeout=10'
DOCKER_BIN=/usr/bin/docker
COMPOSE_BIN=/usr/bin/docker-compose
STACK_NAME=cc

mysql_exec() {
	mysql --defaults-file=/etc/my_cmon.cnf --defaults-group-suffix=_cmon -A -Bse "$*"
}

deploy_container() {
	local cluster_name=$1
	local cluster_type=$2
	local nodes=$3
	local db_root_password=$4
	local vendor=${5:-'percona'}
	local provider_version=${6:-'5.7'}
	local os_user=${7:-'root'}

	echo ">> Deploying ${cluster_name}.. It's gonna take some time.."
	echo ">> You shall see a progress bar in a moment. You can also monitor"
	echo ">> the progress under Activity (top menu) on ClusterControl UI."
	s9s cluster --create --cluster-type=${cluster_type} --nodes="$nodes"  --vendor=${vendor} --provider-version=${provider_version} --db-admin-passwd="${db_root_password}" --os-user=${os_user} --cluster-name="$cluster_name" --wait

	[ $? -ne 0 ] && DEPLOYED=0 || DEPLOYED=1
}

set_container_status() {
	local flag=$1
	local flag_value=$2
	local cluster_name=$3
	local host=$4

	mysql_exec "UPDATE $TBLC SET $flag = $flag_value WHERE ip = '$host' and cluster_name = '$cluster_name'"
}

add_container() {
	local cluster_name=$1
	local hosts=$2

	cid=$(s9s cluster --list -l | grep $cluster_name | awk {'print $1'})
	for host in $hosts; do
		echo ">> Adding $host into $cluster_name"
		s9s cluster --add-node --nodes=$host --cluster-id=${cid} --wait
		if [ $? -eq 0 ]; then
			echo ">> $hosts added."
			set_container_status deployed 1 $cluster_name $host
			set_container_status deploying 0 $cluster_name $host
		else
			echo ">> Job failed. Will retry in the next loop."
			set_container_status deployed 0 $cluster_name $host
			set_container_status deploying 0 $cluster_name $host
		fi
	done
}

check_new_containers_to_scale() {

	scale_cluster=$(mysql_exec "SELECT cluster_name FROM $TBLC GROUP BY cluster_name HAVING SUM(deployed) >= AVG(initial_size) AND SUM(deployed) > 0 AND SUM(deploying) = 0 AND AVG(deployed) < 1 AND AVG(created) = 1")
	if [ ! -z "$scale_cluster" ]; then
		echo ">> Found the following cluster(s) has node(s) to scale:"
		echo "$scale_cluster"
		echo ""

		nodelist=$(mysql_exec "SELECT distinct(ip) FROM $TBLC WHERE cluster_name = '$scale_cluster' AND deployed = 0 AND deploying = 0 AND created = 1")
		trim_nodes=$(echo $nodelist | tr '\n' ' ')

                echo ">> Found a new set of containers awaiting for deployment. Sending scaling command to CMON."
                echo ">> Cluster name         : $scale_cluster"
		echo ">> Nodes to deploy      : $trim_nodes"
		echo ""
		
		add_container "$scale_cluster" "${trim_nodes}"

	fi

}

check_new_cluster_deployment() {
	new_cluster=$(mysql_exec "SELECT cluster_name FROM $TBLC GROUP BY cluster_name HAVING SUM(deployed) <= AVG(initial_size) AND SUM(deployed) = 0 AND SUM(deploying) = 0 AND AVG(created) = 1")
	if [ ! -z "$new_cluster" ]; then
		echo ">> Found the following cluster(s) is yet to deploy:"
		echo "$new_cluster"
		echo ""

		for i in $new_cluster; do
			cluster_size=$(mysql_exec "SELECT initial_size FROM $TBLC GROUP BY cluster_name HAVING cluster_name='$i'")
			number_nodes=$(mysql_exec "SELECT count(ip) FROM $TBLC WHERE cluster_name = '$i'")

			if [ $number_nodes -ge $cluster_size ]; then
				initial_nodes=$(mysql_exec "SELECT DISTINCT(ip) FROM $TBLC WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1 LIMIT $cluster_size")
				all_nodes=$(mysql_exec "SELECT DISTINCT(ip) FROM $TBLC WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				cluster_type=$(mysql_exec "SELECT DISTINCT(cluster_type) FROM $TBLC WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				db_root_password=$(mysql_exec "SELECT DISTINCT(db_root_password) FROM $TBLC WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				vendor=$(mysql_exec "SELECT DISTINCT(vendor) FROM $TBLC WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				provider_version=$(mysql_exec "SELECT DISTINCT(provider_version) FROM $TBLC WHERE cluster_name = '$i' AND deployed = 0 AND deploying = 0 AND created = 1")
				trim_initial_nodes=$(echo $initial_nodes | tr ' ' ';')
				trim_all_nodes=$(echo $all_nodes | tr '\n' ' ')

			        echo ">> Found a new set of containers awaiting for deployment. Sending deployment command to CMON."
        			echo ">> Cluster name         : $i"
			        echo ">> Cluster type         : $cluster_type"
				echo ">> Vendor               : $vendor"
				echo ">> Provider Version     : $provider_version"
			        echo ">> Nodes discovered     : $trim_all_nodes"
			        echo ">> DB root password     : $db_root_password"
				echo ">> Initial cluster size : $cluster_size"
				echo ">> Nodes to deploy      : $trim_initial_nodes"
			        echo ""

				# deploy_container 1cluster_name 2cluster_type 3nodes 4db_root_password 5vendor 6provider_version 7os_user
				deploy_container "$i" "$cluster_type" "${trim_initial_nodes}" "$db_root_password" "$vendor" "$provider_version"
				
				if [ $DEPLOYED -eq 1 ]; then
					# set deployed=1 in cmon.containers
					for n in $initial_nodes; do
						set_container_status deployed 1 $i $n
					done
					echo ">> Deployment of $i has been successfully completed."
				else
				
					echo ">> Deployment of $i is failed. Please refer to ClusterControl activity logs."
				fi
			else
				echo ">> Number of containers for $i is lower ($number_nodes) than its initial size ($cluster_size)."
				echo ">> Nothing to do. Will check again on the next loop."
			fi
		done
	fi
}
remote_copy() {
	local host=$1
	local src=$2
	local dest=$3
	local ssh_user=root

	scp $SCP_OPTS ${src} ${ssh_user}@${host}:${dest} 2> /dev/null
	[ $? -ne 0 ] && echo -e "Remote copy failed: '${host}:${dest}'"
}

remote_cmd() {
	local host=$1
	local cmd=$2
	local ssh_user=root
	
	x=$(ssh $SSH_OPTS ${ssh_user}@${host} "${cmd}" 2> /dev/null)
	[ $? -ne 0 ] && echo -e "Command failed:\n ${cmd}"
	echo $x
}

scale_containers() {
	local cluster_name=$1
	local cluster_size=$2
	local dockercontrol=$3
	local jobid=$4

        platform=$(mysql_exec "SELECT platform FROM $TBLD WHERE host_ip = '$dockercontrol'")
        dc_container=$(mysql_exec "SELECT container_ip FROM $TBLD WHERE host_ip = '$dockercontrol'")
        echo ">> Dockercontrol host: $dockercontrol"
        echo ">> Dockercontrol container: $dc_container"

	if [ $platform == "docker" ]; then
                remote_cmd $dc_container "$COMPOSE_BIN --compose-file=$TARGET_FILE scale $cluster_name=$cluster_size"
	elif [ $platform == "swarm" ]; then
		remote_cmd $dc_container "$DOCKER_BIN service scale ${STACK_NAME}_${cluster_name}=$cluster_size"
	fi
	mysql_exec "UPDATE $TBLJ SET status = 'FINISHED' WHERE jobid = $jobid"
}

create_containers() {
        local cluster_name=$1
        local cluster_type=${2:-'galera'}
        local cluster_size=${3:-3}
        local db_root_password=${4:-'password'}
        local vendor=${5:-'percona'}
        local provider_version=${6:-'5.7'}
	local publish_port=${7:-3306}
	local network=${8:-'default'}
	local dockercontrol=${9}
	local jobid=${10}

	platform=$(mysql_exec "SELECT platform FROM $TBLD WHERE host_ip = '$dockercontrol'")
	dc_container=$(mysql_exec "SELECT container_ip FROM $TBLD WHERE host_ip = '$dockercontrol'")
	echo ">> Dockercontrol host: $dockercontrol"
	echo ">> Dockercontrol container: $dc_container"

	cc_host=$(hostname -i)
	default_port=3306
	if [ $cluster_type == "mongodb" ]; then
		default_port=27017
	elif [ $cluster_type == "postgresql" ]; then
		default_port=5432
	fi

	if [ $platform == "docker" ]; then
		BASE_COMPOSE=/usr/share/cmon/templates/docker-standalone.yml
		COMPOSE_FILE=/tmp/docker-standalone.yml
		TARGET_FILE=/root/docker-standalone.yml

		echo ">> Platform type: docker (standalone)"
		echo
		echo ">> Preparing compose file at $COMPOSE_FILE"
		cp -Rf $BASE_COMPOSE $COMPOSE_FILE
                sed -i "s|_CLUSTER_TYPE_|$cluster_type|g" $COMPOSE_FILE
                sed -i "s|_CLUSTER_NAME_|$cluster_name|g" $COMPOSE_FILE
                sed -i "s|_VENDOR_|$vendor|g" $COMPOSE_FILE
                sed -i "s|_PROVIDER_VERSION_|$provider_version|g" $COMPOSE_FILE
                sed -i "s|_DB_ROOT_PASSWORD_|$db_root_password|g" $COMPOSE_FILE
                sed -i "s|_NETWORK_NAME_|$network|g" $COMPOSE_FILE
                sed -i "s|_CLUSTER_SIZE_|$cluster_size|g" $COMPOSE_FILE
                sed -i "s|_PUBLISH_PORT_|$publish_port|g" $COMPOSE_FILE
		sed -i "s|_DEFAULT_PORT_|$default_port|g" $COMPOSE_FILE
		sed -i "s|_CC_HOST_|$cc_host|g" $COMPOSE_FILE

		echo ">> Copying $COMPOSE_FILE to dockercontrol, $dockercontrol"
		remote_copy $dc_container $COMPOSE_FILE $TARGET_FILE
		echo ">> Creating containers on dockercontrol, $dockercontrol"
                remote_cmd $dc_container "$COMPOSE_BIN -d --compose-file=$TARGET_FILE up"
		echo ">> Scaling up to the desire cluster size ($cluster_size) on dockercontrol, $dockercontrol"
		remote_cmd $dc_container "$COMPOSE_BIN --compose-file=$TARGET_FILE scale $cluster_name=$cluster_size"
		creation_status=1

	elif [ $platform == "swarm" ]; then
                BASE_COMPOSE=/usr/share/cmon/templates/docker-swarm.yml
		COMPOSE_FILE=/tmp/docker-swarm.yml
		TARGET_FILE=/root/docker-swarm.yml

		echo ">> Platform type: docker (swarm)"
                echo
		echo ">> Preparing compose file at $COMPOSE_FILE"
		cp -Rf $BASE_COMPOSE $COMPOSE_FILE
                sed -i "s|_CLUSTER_TYPE_|$cluster_type|g" $COMPOSE_FILE
                sed -i "s|_CLUSTER_NAME_|$cluster_name|g" $COMPOSE_FILE
		sed -i "s|_VENDOR_|$vendor|g" $COMPOSE_FILE
		sed -i "s|_PROVIDER_VERSION_|$provider_version|g" $COMPOSE_FILE
		sed -i "s|_DB_ROOT_PASSWORD_|$db_root_password|g" $COMPOSE_FILE
		sed -i "s|_NETWORK_NAME_|$network|g" $COMPOSE_FILE
		sed -i "s|_CLUSTER_SIZE_|$cluster_size|g" $COMPOSE_FILE
		sed -i "s|_PUBLISH_PORT_|$publish_port|g" $COMPOSE_FILE
		sed -i "s|_DEFAULT_PORT_|$default_port|g" $COMPOSE_FILE
		sed -i "s|_CC_HOST_|$cc_host|g" $COMPOSE_FILE

		echo ">> Compose-file content:"
		cat $COMPOSE_FILE
		echo
		echo ">> Copying $COMPOSE_FILE to dockercontrol, $dockercontrol"
		remote_copy $dc_container $COMPOSE_FILE $TARGET_FILE
		echo ">> Creating containers on dockercontrol, $dockercontrol"
		remote_cmd $dc_container "$DOCKER_BIN stack deploy --compose-file=$TARGET_FILE $STACK_NAME"
		sleep 3
		echo ">> Checking the stack status on dockercontrol, $dockercontrol"
		remote_cmd $dc_container "$DOCKER_BIN stack ps ${STACK_NAME}_${cluster_name}"
		creation_status=1

	elif [ $platform == "kubernetes" ]; then
		BASE_COMPOSE=/usr/share/cmon/templates/docker-kubernetes.yml
		COMPOSE_FILE=/tmp/docker-kubernetes.yml
		TARGET_FILE=/root/docker-kubernetes.yml

		echo "Todo.. Kubernetes"
		#cp -Rf $BASE_COMPOSE $COMPOSE_FILE
	else
		echo "Unable to retrieve container\'s platform. Expected: [ docker | swarm | kubernetes ]"
		creation_status=0
	fi

	if [ $creation_status -eq 1 ]; then
		echo ">> Containers created."
		echo "jobid: $jobid"
		mysql_exec "UPDATE $TBLJ SET status = 'FINISHED' WHERE jobid = $jobid"
	else
		echo ">> Containers creation failed. Will retry in the next cycle."
	fi
}

check_create_containers(){
	create_containers_jid=$(mysql_exec "SELECT jobid FROM $TBLJ WHERE status = 'DEFINED'")
	if [ ! -z "$create_containers_jid" ]; then
		echo ">> Found a CREATE CONTAINERS job as per below:"
		echo "Job ID: $create_containers_jid"
		echo ""
		
		for jid in $create_containers_jid; do
			mysql --defaults-file=/etc/my_cmon.cnf --defaults-group-suffix=_cmon -A -Bse "SELECT jobspec FROM $TBLJ WHERE jobid = $jid" > /tmp/job
			job_json=$(echo -e `cat /tmp/job`)
			job_type=$(echo $job_json | jq -r '.command')
			if [ $job_type == "create_container" ]; then
				local dockercontrol=$(echo $job_json | jq -r '.job_data.docker_control')
				local cluster_name=$(echo $job_json | jq -r '.job_data.cluster_name')
				local cluster_type=$(echo $job_json | jq -r '.job_data.cluster_type')
				local cluster_size=$(echo $job_json | jq -r '.job_data.cluster_size')
				local db_root_password=$(echo $job_json | jq -r '.job_data.db_root_password')
				local vendor=$(echo $job_json | jq -r '.job_data.vendor')
				local provider_version=$(echo $job_json | jq -r '.job_data.provider_version')
				local publish_port=$(echo $job_json | jq -r '.job_data.publish_port')
				local network=$(echo $job_json | jq -r '.job_data.network')

				# create_containers 1cluster_name 2cluster_type 3cluster_size 4db_root_password 5vendor 6provider_version 7publish_port 8network 9dockercontrol 10jobid
                        create_containers "$cluster_name" "$cluster_type" "$cluster_size" "$db_root_password" "$vendor" "$provider_version" "$publish_port" "$network" "$dockercontrol" "$jid"

			elif [ $job_type == "scale_container" ]; then
				local cluster_name=$(echo $job_json | jq -r '.job_data.cluster_name')
				local cluster_size=$(echo $job_json | jq -r '.job_data.cluster_size')
				local dockercontrol=$(echo $job_json | jq -r '.job_data.docker_control')
				# scale_containers 1cluster_name 2cluster_size 3dockercontrol 4jobid
				scale_containers "$cluster_name" "$cluster_size" "$dockercontrol" "$jid"
			fi
		done
	fi
}

while true; do
	check_create_containers
	check_new_cluster_deployment
	check_new_containers_to_scale
	sleep $SLEEP
done
