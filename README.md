# mysql-group-replication-for-k8s
使用helm安装mysql-group-replication 使用proxySQL作为代理

To install the `my-release`:
```bash
helm repo add myrepo https://haolowkey.github.io/helm-chart
helm install my-release myrepo/mysql
```

To uninstall/delete the `my-release`:
```bash
$ helm uninstall my-release
```

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
| ------------------------- | ----------------------------------------------- | ----- |
| `architecture`             | MySQL architecture (`standalone` or `group-replication`)                                                                                                                                  | `group-replication`          |
| `global.auth.username`    | Specify the username of MySQL user to init      | `"testuser"`        |
| `global.auth.password`    | Specify the password of MySQL user to init      | `"testpassword"`    |
| `global.auth.monitorUsername`    | Specify the username of ProxySQL monitor user to init      | `"monitor"`        |
| `global.auth.monitorPassword`    | Specify the password of ProxySQL monitor user to init      | `"monitor"`    |

### Common parameters

| Name                     | Description                                                                                               | Value           |
| ------------------------ | --------------------------------------------------------------------------------------------------------- | --------------- |
| ``                | Install mysql enabled (using Helm capabilities if not set)                                                | `""`            |
| `architecture`           | Support Standalone && Group-Replication architecture mode                                                 | `""`            |

### MySQL common parameters

| Name                       | Description                                                                                                                                                                         | Value                 |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------- |
| `image.registry`           | MySQL image registry                                                                                                                                                                | `docker.io`           |
| `image.repository`         | MySQL image repository                                                                                                                                                              | `haolowkey/mysql`       |
| `image.tag`                | MySQL image tag (immutable tags are recommended)                                                                                                                                    | `8.0.26` |
| `image.pullPolicy`         | MySQL image pull policy                                                                                                                                                             | `IfNotPresent`        |
| `image.pullSecrets`        | Specify docker-registry secret names as an array                                                                                                                                    | `[]`                  |
| `auth.rootPassword`        | Password for the `root` user. Ignored if existing secret is provided                                                                                                                | `""`                  |
| `auth.username`            | Name for a custom user to create                                                                                                                                                    | `""`                  |
| `auth.password`            | Password for the new user. Ignored if existing secret is provided                                                                                                                   | `""`                  |
| `auth.replicationUser`     | MySQL replication user                                                                                                                                                              | `replicator`          |
| `auth.replicationPassword` | MySQL replication user password. Ignored if existing secret is provided                                                                                                             | `""`                  |