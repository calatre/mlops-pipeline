#!/usr/bin/env bash

#On Linux, the quick-start needs to know your host user id and needs to have group id set to 0. 
#Otherwise the files created in dags, logs, config and plugins will be created with root user ownership. 
#You have to make sure to configure them for the docker-compose:
#mkdir -p ./dags ./logs ./plugins ./config
#echo -e "AIRFLOW_UID=$(id -u)" > .env

#Optional: initialize default configs, if you didn't provide a config file
#docker compose run airflow-cli airflow config list

# Initialization Container
docker compose up airflow-init

# After all is done, you can start the Airflow services with:
# docker compose up 

