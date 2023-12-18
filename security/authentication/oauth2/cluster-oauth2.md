## Test steps

- Install olm and apply catalogsource and subscriptions that within zk/bk/pulsar operators
- Scaledown pulsar-operator deployment that managed by olm in your k8s replicas to 0
- Launch your local pulsar-operator by `make run` or debug by your local Developer Tools

- Create encoded credential

```bash
ENCODED_CREDENTIAL=$(echo '{"type":"pulsarinstance","client_id":<your_client_id>,"client_secret":<your_client_secret>,"client_email":"pulsarinstance-kop-3-1@sndev.auth.test.cloud.gcp.streamnative.dev","issuer_url":"https://auth.test.cloud.gcp.streamnative.dev/"}' | base64)
```

- Apply yaml file to create a cluster

**please replace `<your_encoded_credential>` in the yaml file with your real generated encoded credential by previous step at first, and then apply it.**

```bash
k apply -f cluster-oauth2.yaml
```

- Enter container to check and test pularctl

`k exec -it private-cloud-broker-0 -n pulsar bash`

`cat /mnt/secrets/broker_client_credential.json`

`pulsarctl context get`

**output**
```
+---------+---------------+-----------------------+--------------------+
| CURRENT |     NAME      |  BROKER SERVICE URL   | BOOKIE SERVICE URL |
+---------+---------------+-----------------------+--------------------+
| *       | private-cloud | http://localhost:8080 |                    |
+---------+---------------+-----------------------+--------------------+
```

`pulsarctl oauth2 activate`

**output**
```
Logged in as pulsarinstance-kop-3-1@sndev.auth.test.cloud.gcp.streamnative.dev.
Welcome to Pulsar!
```

`pulsarctl tenants list`

**output**
```
+-------------+
| TENANT NAME |
+-------------+
| public      |
| pulsar      |
| sn          |
+-------------+
```
