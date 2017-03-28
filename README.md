# ClusterControl Docker Image - Docker Prototype version#

## Run on Swarm (recommended) ##

Ensure Swarm is installed and initialized. ClusterControl and DockerControl supposed to be running together. The simplest way to run them is by using the compose file, `docker-compose.yml`:
```bash
# cd to clustercontrol-dev git directory
$ docker stack deploy --compose-file=docker-compose.yml cc
```

Details at [Google Slides] (https://docs.google.com/a/severalnines.com/presentation/d/1jraugZ62deHye8o7b1ibnBxKHGccEEm1dhiSwYbJnO0/edit?usp=sharing).
