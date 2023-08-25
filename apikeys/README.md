## test with kind
- kind create cluster
- install olm, refer https://docs.streamnative.io/operator/pulsar-operator-install-olm, `curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.23.1/install.sh | bash -s v0.23.1`
- k apply -f catalogsource.yaml
- k apply -f subscriptions.yaml
- k create ns pulsar
- comment the apikey configurations code in this yaml file 
- k apply -f cluster.yaml
- downscale sn-operator, edit the deployment replicas to 0 of sn-operator in namespace operators
- make install
- export OPERATOR_NAMESPACE=operators WEBHOOK_SERVER_CERT=sn-operator-controller-manager-service-cert
- make copy-running-certs
- WEBHOOK_SERVICE_ADDRESS=https://host.docker.internal:9443 make webhook-proxy
- OPERATOR_NAMESPACE=operators;SN_OPERATOR_FLINK_ENABLE=false;SN_OPERATOR_PFSQL_ENABLE=false make run
- uncomment the apikey configurations code in this yaml file  
- k apply -f cluster.yaml
- kgsec private-cloud-apikeys-key -n pulsar -o json | jq -r .data.token | base64 -d
- k port-forward svc/private-cloud-apikeys -n pulsar 8081:8081
- k port-forward svc/private-cloud-broker -n pulsar 8080:8080
- k port-forward svc/private-cloud-streamnative-console -n pulsar 9527:9527
## debug console
- kgsec private-cloud-apikeys-key -n pulsar -o json | jq -r '.data.token' | base64 -d > super-token
- mvn clean package
- java --add-opens java.base/java.time=ALL-UNNAMED -cp "./target/classes:./target/build/libs/*" io.streamnative.gateway.Application
- launch console application with debug model

List of problems:
- The version of pulsar-operator is wrong, it needs to be upgraded to 0.17.5, the solution is to create the catalogsource of sn, refer to sn-catalogsource.yaml
- The apikeys log reports that Pulsar is not available, and the broker log reports that the number of bookies is insufficient. The reason: because the replicas configuration is 1, which is inconsistent with the write configuration. The solution is to add the configuration PULSAR_PREFIX_managedLedgerDefaultEnsembleSize: "1";PULSAR_PREFIX_managedLedgerDefaultWriteQuorum: "1"; PULSAR_PREFIX_managedLedgerDefaultAckQuorum: "1"
- Console startup error imageCapabilities null pointer, the reason is that imageCapabilities failed to load because of wrong namespace (default sn_system), the solution is to add startup environment variable OPERATOR_NAMESPACE=operators
- To avoid the conflict between the installed sn-operator and the debug sn-operator, modify the deployment replicas of the installed sn-operator to 0
- Because of the webhook penetration problem, it is recommended to use kind to deploy the test locally