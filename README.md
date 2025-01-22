# check_etcd_version.sh

## Description

This bash script will retieve the ETCD version for the desired RHOCP releases

## Usage

### Basic Usage

Simply run the script with the desired option(s)

```bash
usage: check_etcd_version.sh [-a <Arch>] [-r <release>] [-m <minor_version>] [-p <pull-secret>] [-kc] [-h]
```

### Script Options

```text
usage: check_etcd_version.sh [-a <Arch>] [-r <release>] [-m <minor_version>] [-p <pull-secret>] [-kc] [-h]
|------------------------------------------------------------------------------------------------------------|
| Options | Description                                                     | [Defaults]                     |
|---------|-----------------------------------------------------------------|--------------------------------|
|      -a | Architecture used to check the image                            | x86_64                         |
|      -r | List of release version(s) to check                             |                                |
|      -m | List of minor version(s) to check                               |                                |
|      -p | Path of the pull-secret file                                    | local 'pull-secret' from $HOME |
|      -k | Display the output as KCS format                                | false                          |
|      -c | Clear the images                                                | false                          |
|---------|-----------------------------------------------------------------|--------------------------------|
|         | Additional Options:                                             |                                |
|---------|-----------------------------------------------------------------|--------------------------------|
|      -h | display this help and check for updated version                 |                                |
|------------------------------------------------------------------------------------------------------------|

Current Version: X.Y.Z
```

### Examples

* Check multiple releases _(default archictecture)_.

  ```bash
  check_etcd_version.sh -p ./<pull_secret_file> -r 4.14.0,4.15.0,4.16.0 -r 4.17.0
  ```

* Check the RHOCP minor versions _(default archictecture)_ formatting the output in KCS table.

  ```bash
  check_etcd_version.sh -p ./<pull_secret_file> -m 4.16,4.17 -m 4.15 -k
  ```

* Mixing Release and Minor versions, and cleaning the images once the script is completed.

  ```bash
  check_etcd_version.sh -p ./<pull_secret_file> -a x86_64 -r 4.14.0,4.15.0 -m 4.16 -c
  ```
