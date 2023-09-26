include .env

help:
	@echo "## docker-build	- Build Docker Images (amd64) including its inter-container network."
	@echo "## docker-build-arm	- Build Docker Images (arm64) including its inter-container network."
	@echo "## postgres		- Run a Postgres container."
	@echo "## spark		- Run a Spark cluster, rebuild the postgres container, then create the destination tables."
	@echo "## jupyter		- Spinup jupyter notebook for testing and validation purposes."
	@echo "## airflow		- Spinup airflow scheduler and webserver."
	@echo "## kafka		- Spinup kafka cluster (Kafka+Zookeeper)."
	@echo "## spark-produce and spark-consume	- Start a Spark streaming job producer and consumer."
	@echo "## clean		- Cleanup all running containers related to the challenge."

docker-build:
	@echo '__________________________________________________________'
	@echo 'Building Docker Images ...'
	@echo '__________________________________________________________'
	@docker network create dataeng-network
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/spark -f ./docker-day-18/Dockerfile.spark .
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/airflow -f ./docker-day-18/Dockerfile.airflow .
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/jupyter -f ./docker-day-18/Dockerfile.jupyter .
	@echo '==========================================================='

docker-build-arm:
	@echo '__________________________________________________________'
	@echo 'Building Docker Images ...'
	@echo '__________________________________________________________'
	@docker network create dataeng-network
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/spark -f ./docker-day-18/Dockerfile.spark .
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/airflow -f ./docker-day-18/Dockerfile.airflow-arm .
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/jupyter -f ./docker-day-18/Dockerfile.jupyter .
	@echo '==========================================================='

jupyter:
	@echo '__________________________________________________________'
	@echo 'Creating Jupyter Notebook Cluster at http://localhost:${JUPYTER_PORT} ...'
	@echo '__________________________________________________________'
	@docker-compose -f ./docker-day-18/docker-compose-jupyter.yml --env-file .env up -d
	@echo 'Created...'
	@echo 'Check logs for more details token...'
	@echo '==========================================================='

spark:
	@echo '__________________________________________________________'
	@echo 'Creating Spark Cluster ...'
	@echo '__________________________________________________________'
	@docker-compose -f ./docker-day-18/docker-compose-spark.yml --env-file .env up -d
	@echo '==========================================================='

spark-submit-test:
	@docker exec ${SPARK_WORKER_CONTAINER_NAME}-1 \
		spark-submit \
		--master spark://${SPARK_MASTER_HOST_NAME}:${SPARK_MASTER_PORT} \
		/spark-scripts/spark-example.py

spark-submit-airflow-test:
	@docker exec ${AIRFLOW_WEBSERVER_CONTAINER_NAME} \
		spark-submit \
		--master spark://${SPARK_MASTER_HOST_NAME}:${SPARK_MASTER_PORT} \
		--conf "spark.standalone.submit.waitAppCompletion=false" \
		--conf "spark.ui.enabled=false" \
		/spark-scripts/spark-example.py

airflow:
	@echo '__________________________________________________________'
	@echo 'Creating Airflow Instance ...'
	@echo '__________________________________________________________'
	@docker-compose -f ./docker-day-18/docker-compose-airflow.yml --env-file .env up -d
	@echo '==========================================================='

postgres: postgres-create postgres-create-table postgres-ingest-csv

postgres-create:
	@docker-compose -f ./docker-day-18/docker-compose-postgres.yml --env-file .env up -d
	@echo '__________________________________________________________'
	@echo 'Postgres container created at port ${POSTGRES_PORT}...'
	@echo '__________________________________________________________'
	@echo 'Postgres Docker Host	: ${POSTGRES_CONTAINER_NAME}' &&\
		echo 'Postgres Account	: ${POSTGRES_USER}' &&\
		echo 'Postgres password	: ${POSTGRES_PASSWORD}' &&\
		echo 'Postgres Db		: ${POSTGRES_DB}'
	timeout 5
	@echo '==========================================================='

postgres-create-table:
	@echo '__________________________________________________________'
	@echo 'Creating tables...'
	@echo '_________________________________________'
	@docker exec -it ${POSTGRES_CONTAINER_NAME} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -f sql/ddl-retail.sql
	@echo '==========================================================='

postgres-ingest-csv:
	@echo '__________________________________________________________'
	@echo 'Ingesting CSV...'
	@echo '_________________________________________'
	@docker exec -it ${POSTGRES_CONTAINER_NAME} psql -U ${POSTGRES_USER} -d ${POSTGRES_DB} -f sql/ingest-retail.sql
	@echo '==========================================================='

kafka: kafka-create-cluster kafka-create-topic

kafka-create-cluster:
	@echo '__________________________________________________________'
	@echo 'Creating Kafka Cluster ...'
	@echo '__________________________________________________________'
	@docker-compose -f ./docker-day-18/docker-compose-kafka.yml --env-file .env up -d
	@echo 'Waiting for uptime on http://localhost:8083 ...'
	timeout 20
	@echo 'creating topic ${KAFKA_TOPIC_NAME} now, please wait..'

kafka-create-topic:
	@docker exec ${KAFKA_CONTAINER_NAME} \
		kafka-topics.sh --create \
		--partitions ${KAFKA_PARTITION} \
		--replication-factor ${KAFKA_REPLICATION} \
		--bootstrap-server localhost:9092 \
		--topic ${KAFKA_TOPIC_NAME}

spark-produce:
	@echo '__________________________________________________________'
	@echo 'Producing fake events ...'
	@echo '__________________________________________________________'
	@docker exec ${SPARK_WORKER_CONTAINER_NAME}-1 \
		python \
		/scripts/event_producer.py \

spark-consume:
	@echo '__________________________________________________________'
	@echo 'Consuming fake events ...'
	@echo '__________________________________________________________'
	@docker exec ${SPARK_WORKER_CONTAINER_NAME}-1 \
		spark-submit \
		/spark-scripts/spark-event-consumer.py \

clean:
	@bash ./scripts/goodnight.sh