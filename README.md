# mysql-group-replication-for-k8s
使用helm安装mysql-group-replication 使用proxySQL作为代理

To install the `my-release`:
```bash
helm repo add mysqlrepo https://haolowkey.github.io/helm-mysql
helm install my-release mysqlrepo/mysql
```

To uninstall/delete the `my-release`:
```bash
$ helm uninstall my-release
```

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
| ------------------------- | ----------------------------------------------- | ----- |
| `global.architecture`     | MySQL architecture (`standalone` or group-replication`) | `group-replication` |
| `global.auth.username`    | Name for a custom user to create | `""` |
| `global.auth.password`    | Password for the new user | `""` |
| `global.auth.monitorUsername`    | Name for ProxySQL user to create | `""` |
| `global.auth.monitorPassword`    | Password for ProxySQL ser to create | `""` |

### MySQL common parameters

| Name                       | Description                                                                                                                                                                         | Value                 |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `image.registry`           | MySQL image registry                                                                                                                                                                | `docker.io`           |
| `image.repository`         | MySQL image repository                                                                                                                                                              | `haolowkey/mysql`       |
| `image.tag`                | MySQL image tag (immutable tags are recommended)                                                                                                                                    | `8.0.26` |
| `image.pullPolicy`         | MySQL image pull policy                                                                                                                                                             | `IfNotPresent`        |
| `image.pullSecrets`        | Specify docker-registry secret names as an array                                                                                                                                    | `[]`                  |
| `auth.replicationUser`     | MySQL replication user                                                                                                                                                              | `replicator`          |
| `auth.replicationPassword` | MySQL replication user password. Ignored if existing secret is provided                                                                                                             | `""`                  |