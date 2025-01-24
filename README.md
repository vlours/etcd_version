# check_etcd_version.sh

## Description

This bash script will retieve the ETCD version for the desired RHOCP releases

The script has the following dependencies:

- `podman`
  - To download on Linux: `yum module install container-tools`
  - To download on MacOS & others: <https://podman-desktop.io/downloads>
- `oc`
  - Please download from:  <https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/>
- `yq`
  - To download on Linux: `wget https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_386.tar.gz`
  - To download on MacOS: `brew install yq`
- `jq`
  - To download on Linux: `yum install jq`
  - To download on MacOS: `brew install jq`

## Usage

### Basic Usage

Simply run the script with the desired option(s)

```bash
usage: check_etcd_version.sh -r <release> | -m <minor_version> [-p <pull-secret>] [-a <Arch>] [-kcy] [-h]
```

### Script Options

```text
usage: check_etcd_version.sh -r <release> | -m <minor_version> [-p <pull-secret>] [-a <Arch>] [-kcy] [-h]
|------------------------------------------------------------------------------------------------------------|
| Options | Description                                                     | [Defaults]                     |
|---------|-----------------------------------------------------------------|--------------------------------|
|      -r | List of release version(s) to check                             |                                |
|      -m | List of minor version(s) to check                               |                                |
|      -p | Path of the pull-secret file                                    | local 'pull-secret' from $HOME |
|      -a | Architecture used to check the image                            | x86_64                         |
|      -k | Display the output as KCS format                                | false                          |
|      -c | Clear the images                                                | false                          |
|      -y | Automatically retry/continue if 'podman pull' failed            | false                          |
|---------|-----------------------------------------------------------------|--------------------------------|
|         | Additional Options:                                             |                                |
|---------|-----------------------------------------------------------------|--------------------------------|
|      -h | display this help and check for updated version                 |                                |
|------------------------------------------------------------------------------------------------------------|

Current Version: X.Y.Z
```

### Examples

- Check multiple releases _(default archictecture)_.

  ```bash
  check_etcd_version.sh -p ./<pull_secret_file> -r 4.14.0,4.15.0,4.16.0 -r 4.17.0
  ```

- Check the RHOCP minor versions _(default archictecture)_, formatting the output in KCS table, and automatically retry if `podman pull` failed.

  ```bash
  check_etcd_version.sh -p ./<pull_secret_file> -m 4.16,4.17 -m 4.15 -ky
  ```

- Mixing Release and Minor versions, and cleaning the images once the script is completed.

  ```bash
  check_etcd_version.sh -p ./<pull_secret_file> -a x86_64 -r 4.14.0,4.15.0 -m 4.16 -c
  ```
