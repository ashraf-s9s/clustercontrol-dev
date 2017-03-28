# ClusterControl Docker Image - Development (nightly) version#

## Table of Contents ##

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Image Description](#image-description)
4. [Run Container](#run-container)
5. [Optional Docker System Environment](#optional-docker-system-environment)
6. [Build Image](#build-image)
7. [Add an Existing Server/Cluster](#add-an-existing-cluster)
8. [Limitations](#limitations)
9. [Development](#development)

## Overview ##

ClusterControl is a management and automation software for database clusters. It helps deploy, monitor, manage and scale your database cluster. This Docker image comes with ClusterControl installed and configured with all of its components so you can immediately use it to manage and monitor an existing database infrastructure. 

Supported database servers/clusters:
* Galera Cluster for MySQL
* Percona XtraDB Cluster
* MariaDB Galera Cluster
* MySQL replication
* MySQL single instance
* MySQL Cluster (NDB)
* MongoDB/TokuMX sharded cluster
* MongoDB/TokuMX replica set
* PostgreSQL single instance

More details at [Severalnines](http://www.severalnines.com/clustercontrol) website.

## Image Description ##

To pull ClusterControl images, simply:
```bash
$ docker pull severalnines/clustercontrol:nightly
```

The image consists of ClusterControl and all of its components:
* ClusterControl controller, cmonapi, UI and NodeJS packages installed via Severalnines repository.
* MySQL, CMON database, cmon user grant and dcps database for ClusterControl UI.
* Apache, file and directory permission for ClusterControl UI with SSL installed.
* An auto-generated SSH key for ClusterControl usage.

## Run Container ##

To run a ClusterControl container, the simplest command would be:
```bash
$ docker run -d severalnines/clustercontrol:nightly
```

However, we would recommend users to assign a container name and map the host's port with exposed HTTP or HTTPS port on container:
```bash
$ docker run -d --name clustercontrol -p 5000:80 severalnines/clustercontrol:nightly
```

Verify with:
```bash
$ docker logs -f clustercontrol
$ docker ps # ensure the container is started and running
```

After a moment, you should able to access the ClusterControl Web UI at http://[host's IP address]:[host's port]/clustercontrol, for example:
**http://192.168.10.100:5000/clustercontrol**

To access the ClusterControl's console:
```bash
$ docker exec -it clustercontrol /bin/bash
```

## Optional Docker System Environment ##

* `CMON_PASSWORD`: MySQL password for user 'cmon'. Default to 'cmon'.
* `MYSQL_ROOT_PASSWORD`: MySQL root password for the ClusterControl container. Default to 'password'.

Use -e flag to specify the environment variable, for example:
```bash
$ docker run -d --name clustercontrol -e CMON_PASSWORD=MyCM0nP4ss -e MYSQL_ROOT_PASSWORD=MyR00tP4ss severalnines/clustercontrol
```

* -p : Map the exposed port from host to the container. By default following ports are exposed on the container:
	* 22 - SSH
	* 80 - HTTP
	* 443 - HTTPS
	* 3306 - MySQL
	* 9500 - cmon RPC
	* 9600 - HAproxy stats (if HAproxy is installed in this container)
	* 9999 - netcat (backup streaming)

Use -p flag to map ports between host and container, for example to map HTTP and HTTPS of ClusterControl UI, simply run the container with:
```bash
$ docker run -d --name clustercontrol -p 5000:80 -p 5443:443 severalnines/clustercontrol
```

## Build Image ##

To build Docker image, download the Docker related files available at [our Github repository](https://github.com/severalnines/docker):
```bash
$ git clone https://github.com/ashraf-s9s/clustercontrol-docker
$ cd clustercontrol-docker
$ docker build -t severalnines/clustercontrol:nightly .
```

Verify with:
```bash
$ docker images
```

## How to Use ##

1) Run the ClusterControl container:
```bash
docker run -d --name clustercontrol -p 5000:80 severalnines/clustercontrol:nightly
```

2) Run the DB containers (replace `CC_HOST` value accordingly):
```bash
docker run -d --name galera1 -p 6661:3306 -e CC_HOST=172.17.0.2 -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera2 -p 6662:3306 -e CC_HOST=172.17.0.2 -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera3 -p 6663:3306 -e CC_HOST=172.17.0.2 -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
```

3) ClusterControl will automatically pick the new containers to deploy. If it finds the number of containers is equal or greater than `INITIAL_CLUSTER_SIZE`, the cluster deployment shall begin. You can verify that with:
```bash
docker logs -f clustercontrol
```

Or, open ClusterControl UI and look under Activity (top menu).


4) To scale up, just create another nodes and ClusterControl will add into the cluster automatically:
```bash
docker run -d --name galera4 -p 6664:3306 -e CC_HOST=172.17.0.2 -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
docker run -d --name galera5 -p 6665:3306 -e CC_HOST=172.17.0.2 -e CLUSTER_TYPE=galera -e CLUSTER_NAME=mygalera -e INITIAL_CLUSTER_SIZE=3 severalnines/centos-ssh
```
5) Repeat step #3.

## Development ##

Please report bugs, improvements or suggestions via our support channel: [https://support.severalnines.com](https://support.severalnines.com) 

If you have any questions, you are welcome to get in touch via our [contact us](http://www.severalnines.com/contact-us) page or email us at info@severalnines.com.
