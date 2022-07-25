# mysql-group-replication-for-k8s
使用helm安装mysql-group-replication 使用proxySQL作为代理

打包
```
helm package .
```

To install the `my-release`:
```
helm install my-release ./
```

To uninstall/delete the `my-release`:

```bash
$ helm delete my-release
```

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
| ------------------------- | ----------------------------------------------- | ----- |
| `global.mysql.secretName` | Global mysql secret                             | `""`  |


### Common parameters

| Name                     | Description                                                                                               | Value           |
| ------------------------ | --------------------------------------------------------------------------------------------------------- | --------------- |
| `enabled`                | Install mysql enabled (using Helm capabilities if not set)                                                | `""`            |
| `architecture`           | Support Standalone && Group-Replication architecture mode                                                 | `""`            |