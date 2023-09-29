include .env

help:
	@echo "## build		- Build Docker Images (amd64) including its inter-container network."
	@echo "## spark		- Run a Spark cluster."
	@echo "## jupyter		- Spinup jupyter notebook for testing and validation purposes."
	@echo "## kafka		- Spinup kafka cluster (Kafka+Zookeeper) and Create test-topic."
	@echo "## spark-produce	- Start a Spark streaming job producer."
	@echo "## spark-consume	- Start a Spark streaming job consumer."

build:
	@echo '__________________________________________________________'
	@echo 'Building Docker Images ...'
	@echo '__________________________________________________________'
	@docker network create dataeng-network
	@echo '__________________________________________________________'
	@docker build -t dataeng-dibimbing/spark -f ./docker-day-18/Dockerfile.spark .
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
		/spark-scripts/kafka-event-producer.py

spark-consume:
	@echo '__________________________________________________________'
	@echo 'Consuming fake events ...'
	@echo '__________________________________________________________'
	@docker exec ${SPARK_WORKER_CONTAINER_NAME}-1 \
		spark-submit \
		/spark-scripts/spark-event-consumer.py