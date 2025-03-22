# Apache Flink
* [First steps](https://nightlies.apache.org/flink/flink-docs-stable/docs/try-flink/local_installation/)
* [Download Apache Flink](https://flink.apache.org/downloads/)
* [Apache Flinke v1.20.0](https://github.com/apache/flink/tree/release-1.20.0)

# Apache Flink とは
Apache Flink とは、ストリームとバッチを処理するための分散処理フレームワークです。
Flink は、大規模データ処理のために設計されており、高いスループットと低いレイテンシを実現します。
Flink は、ストリームプロセッシングエンジンとしての機能だけでなく、バッチ処理エンジンとしての機能も提供しています。

# 耐障害性
Flink はチェックポイントメカニズムを使用して、耐障害性を実現しています。
チェックポイントは、Flink に定期的にアプリケーションの状態を保持するスナップショットを取らせます。
そして、障害フェースに入ると、最新のチェックポイントからアプリケーションの状態を自動復旧できます。

# パフォーマンス

## 並列処理
Flink はデータを複数のタスクに分割して並行して実行することで、データの並列処理を可能にします。これにより、リソースの効率的な利用と高速な処理が実現されます。

## メモリ管理
Flink はメモリプーリングやオフヒープストレージなどの効率的なメモリ管理技術を採用しており、ガベージコレクションのオーバーヘッドを最小化し、全体的なパフォーマンスを向上させています。

## ストリーミング
Flink のストリーミングエンジンは、低レイテンシで連続的なデータストリームを処理するために設計されています。
イベントタイム処理、ウィンドウ処理、状態を持つ計算などをサポートし、ストリーミングデータ上でのリアルタイム分析を可能にします。

## バッチ処理
ストリーミングに加えて、Flink はバッチ処理の機能も提供しています。
オペレーターチェーン、データのローカリティ、パイプライン実行などのさまざまな最適化を行い、バッチジョブの最適化を図ります。

## 最適化された実行エンジン
Flink の実行エンジンは、データ処理タスクを効率的に実行するために設計されています。パイプライニング、遅延評価、動的最適化などの技術を活用して、オーバーヘッドを最小化し、スループットを最大化します。  


# 実際に動かしてみる

## 構成
* [Anatomy of a Flink Cluster](https://nightlies.apache.org/flink/flink-docs-master/docs/concepts/flink-architecture/#anatomy-of-a-flink-cluster)  

`./bin/start-cluster.sh` を実行して、JobManager とTaskManager デーモンを起動します。
起動後、Word Counter のサンプルFlink Program を起動します。

## 手順

```
docker network create --driver=bridge --subnet=192.168.153.0/24 bridge2

docker run --rm --name flink --network bridge2 \
    --volume ${PWD}:/opt -ti debian:bookworm-slim bash -c "cd /opt; bash -l"
apt-get update
apt-get install openjdk-17-jdk wget
java -version
> ...
wget https://dlcdn.apache.org/flink/flink-1.20.0/flink-1.20.0-bin-scala_2.12.tgz
tar -xzf flink-1.20.0-bin-scala_2.12.tgz
cd flink-1.20.0 && ls -l
./bin/start-cluster.sh
> Starting cluster.
> Starting standalonesession daemon on host f84a8aeff47c.
> Starting taskexecutor daemon on host f84a8aeff47c.

ps aux | grep flink
> root         779  2.8  0.2 8023148 296676 pts/0  Sl   14:56   0:08 /usr/local/openjdk-11/bin/java ...

./bin/stop-cluster.sh
```

## flink job を登録してみる
in-memory で動かす方法。
```
tail -F log/flink-*-taskexecutor-*.out
./bin/flink run examples/streaming/WordCount.jar
```

input をファイルで実行する方法。
```
cat << 'EOF' > a.txt
Nascetur mauris lectus commodo malesuada taciti venenatis curae; tempus torquent integer enim curabitur ultrices dictum lacinia cras sit fames ullamcorper torquent varius curabitur, hymenaeos nam tellus duis ligula Porta tincidunt erat. Purus. Vitae blandit, fusce litora. Viverra, viverra, dictumst elementum ultrices nascetur sapien primis sem leo.
EOF

tail -F log/flink-*-taskexecutor-*.out
./bin/flink run examples/streaming/WordCount.jar --import ${PWD}/a.txt
```

## Kafka source
* [Developing event-driven applications with Kafka and Docker](https://docs.docker.com/guides/kafka/)

Kafka を準備する。
```
docker run -d --name=kafka -p 9092:9092 apache/kafka
```

Kafka が起動していることを確認。
```
docker exec -ti kafka /opt/kafka/bin/kafka-cluster.sh cluster-id --bootstrap-server :9092
> Cluster ID: xxxxxxxxx-xxxxx--xxxxx
```

topic を作成し、メッセージを送信する(produce)。
```
docker exec -ti kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server :9092 --topic demo
> Vel, conubia dis mollis eget dictumst ultrices mauris pulvinar faucibus.
> Natoque placerat massa turpis pellentesque maecenas venenatis penatibus id. Suspendisse tristique eu vel fusce turpis.
> (Ctrl + C)
```

初回だけ、下記のようなメッセージが出力されるが、問題なし。
このメッセージを持って、トピックが作成される。
```
[2024-12-01 10:17:16,519] WARN [Producer clientId=console-producer] Error while fetching metadata with correlation id 6 : {demo=UNKNOWN_TOPIC_OR_PARTITION} (org.apache.kafka.clients.NetworkClient)
```

Kafka のトピックに登録したメッセージをコンシュームします。
```
docker exec -ti kafka /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server :9092 --topic demo --from-beginning
> Vel, conubia dis mollis eget dictumst ultrices mauris pulvinar faucibus.
> Natoque placerat massa turpis pellentesque maecenas venenatis penatibus id. Suspendisse tristique eu vel fusce turpis.
```

Kafka を使うサンプルアプリ。
* [Building a Data Pipeline with Flink and Kafka](https://www.baeldung.com/kafka-flink-data-pipeline)
* [eugenp/tutorials](https://github.com/eugenp/tutorials/tree/master/apache-kafka-2)
* [Build an Apache Flink Application from Scratch in 5 Minutes](https://alibaba-cloud.medium.com/build-an-apache-flink-application-from-scratch-in-5-minutes-a252741d24b2)
* [redpand-data/flink-kafka-examples](https://github.com/redpanda-data/flink-kafka-examples)

```
##sudo rm -rf my-flink-project
##docker run --rm --name maven --hostname maven -v ${PWD}:/opt -i debian:bookworm-slim bash << 'EOF'
##cd /opt
##apt-get update
##apt-get install -y openjdk-17-jdk maven
##mvn archetype:generate \
##    -DarchetypeGroupId=org.apache.flink \
##    -DarchetypeArtifactId=flink-quickstart-java \
##    -DarchetypeVersion=1.20.0 \
##    -DgroupId=my-flink-project \
##    -DartifactId=my-flink-project \
##    -Dversion=0.1 \
##    -Dpackage=myflink \
##    -DinteractiveMode=false
##EOF
##sudo chown -R tsutomu:tsutomu my-flink-project
```

```
https://github.com/hobby-labs/my-flink-project.git
```

## IntelliJ 実行時のエラー
```
Run -> (Open Run/Debug Configurations window) -> Modify options -> Turn on "Add dependencies with "provided"" scope to classpath
```

