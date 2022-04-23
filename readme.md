# Docker image for general CI

Docker image for general CI.
Image has a pre-created user "ci_user", which, if run with default entrypoint script, can change its id to match id of user on the host machine.

[![GitHub Actions Status](https://github.com/rudenkornk/docker_ci/actions/workflows/workflow.yml/badge.svg)](https://github.com/rudenkornk/docker_ci/actions)


## Build
```shell
make rudenkornk/docker_ci
```

## Test
```shell
make check
```

## Run
```shell
CI_BIND_MOUNT=$(pwd) make docker_ci_container

docker attach docker_ci_container
# OR
docker exec -it docker_ci_container bash -c "source ~/.profile && bash"
```

## Clean
```shell
make clean
# Optionally clean entire docker system and remove ALL containers
./clean_all_docker.sh
```

## Different use cases for this repository
This repository supports two different scenarios

### 1. Use it in your CI
For example, in GitHub Actions that might look like:

```yaml
jobs:
  build:
    runs-on: "ubuntu-20.04"
    container:
      image: rudenkornk/docker_ci:0.1.0
    steps:
      # some build steps
```

### 2. Use image for your local testing

```shell
docker run --interactive --tty \
  --user ci_user \
  --env CI_UID="$(id --user)" --env CI_GID="$(id --group)" \
  --mount type=bind,source="$(pwd)",target=/home/repo \
  rudenkornk/docker_ci:latest
```

Instead of `$(pwd)` use path to your repo.
It is recommended to mount it into `/home/repo`.
Be careful if mounting inside `ci_user`'s home directory (`/home/ci_user`): entrypoint script will change rights to what is written in `CI_UID` and `CI_GID` vars of everything inside home directory.

