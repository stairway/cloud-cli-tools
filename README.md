# Cloud CLI Tools

## **Table of Contents**

1. [Summary](#summary)
1. [Setup Requirements](#setup-requirements)
   1. [Required Dependencies](#required-dependencies)
1. [Setup Instructions](#setup-instructions)
   1. [Run Only](#run-only)
   1. [Build & Run](#build--run)
      1. [Step 1 - Extract](#step-1-extract)
      1. [Step 2 - First Build](#step-2-first-build)
   1. [Run Instructions](#run-instructions)
      1. [Step 3 - Run](#step-3-run)
1. [Command Overview](#command-overview)
   1. [Reboot](#reboot)
   1. [Reset](#reset)
   1. [Resetter Wrapper](#resetter-wrapper)
   1. [Build](#build)
      1. [buildx](#buildx)
   1. [Run](#run)
1. [Detailed Overview](#project-overview)
   1. [Project Structure](#project-structure)
   1. [File Persistence](#file-persistence)
      1. [Standard Data](#standard-data)
      1. [Password Data](#password-data)

## **Summary**

A self contained ubuntu docker environment, with all necessary cli tools already configured. 

**File Persistence**

Certain files and folders are persisted from the container. It is 100% safe to run, as no pre-existing files on your machine will be modified. [Read more](#file-persistence).

Password data is encrypted and persisted in an obfuscated directory.

## **Setup Requirements**

### Required dependencies
* [docker](https://docs.docker.com/get-docker/)
* [jq](https://stedolan.github.io/jq/download/)
* [buildx](https://www.docker.com/blog/how-to-rapidly-build-multi-architecture-images-with-buildx/) (only required for building)

**\*NOTE\***

If you're having trouble building, check if you have Experimental Features enabled in the Settings for Docker Desktop. If it's enabled, then disable it.

### **Run Instructions**

```bash
$ bin/run.sh
```

## **Command Overview**

### **Reboot**
(`bin/reboot.sh`)

Same as a `quick` reset: `bin/_resetter.sh`

(See [Resetter Wrapper](#resetter-wrapper) below, for more info)

_Usage:_
```
bin/reboot.sh
```

### **Reset**
(`bin/reset.sh`)

Same as a `full` reset: `bin/_resetter.sh -F`

(See [Resetter Wrapper](#resetter-wrapper) below, for more info)

_Usage:_
```
bin/reset.sh
bin/reset.sh [OPTIONS]
```

### **Resetter Wrapper**
(`bin/_resetter.sh`)

2 types of reset: **_quick_** and **_full_**

The `quick` reset is like a reboot, and the `full` reset is like a system reset.

_Usage:_
```
bin/_resetter.sh
bin/_resetter.sh [OPTIONS]
```

#### **Options**

**`No Flags` -- `bin/_resetter.sh`**: _**Quick** mode. Destroys container. All other persisted files will remain untouched._

**`-F | --full`**: _**Full** mode. Destroys container and persisted dotfiles. Preserves aws creds. (~/.ssh folder will remain untouched)_

**`-D | --deep`**: _**Deep** mode. Performs a full reset, deletes aws creds, deletes volume. (~/.ssh folder will remain untouched)_

_**Complete** mode. Performs a complete reset. Deletes it all. Perform a `--deep` (`-D`) reset, and then remove the project (`cloud-cli-tools`) directory. Reinstall from scratch using the `cct` script_

#### **Examples**

```bash
# Example 1
$ bin/_resetter.sh
# Example 2
$ bin/_resetter.sh -F
# Example 3
$ bin/_resetter.sh -D
# Example 4
$ bin/_resetter.sh -D && cd .. && rm -rf cloud-cli-tools
```

### **Build**
(`bin/build.sh`)

2 types of build: **_quick_** and **_full_**

_Usage:_
```bash
bin/build.sh
bin/build.sh [OPTIONS] [ADDITIONAL_ARGS]
```

#### **buildx**
The build script uses buildx to create a _multi-arch_ image.

_**IMPORTANT** - Buildx **must** be setup._

**Some additional steps are required:**
1. Create builder instance

   ```bash
   docker buildx create --name mybuilder --use --bootstrap
   docker buildx inspect --bootstrap
1. Setup Prune Danglers

   ```bash
   alias docker_clean='echo y | docker buildx prune && echo y | docker image prune'
1. Run build script

   ```bash
   REGISTRY_USERNAME="$DOCKER_HUB_USER" REGISTRY_PASSWORD="$DOCKER_HUB_PAT" bin/build.sh [OPTIONS]
1. Cleanup

   ```bash
   docker_clean
<br>

#### **Options**

**`No Flags` -- `bin/build.sh`**: _**Quick** mode. Quick rebuild. Does not build parent image, so quick builds are not intended for the [first build](#step-2-first-build)_

**`-F | --full`**: _Full (deep) build. Required for first build. Builds all necessary images._

**`-N | --no-cache`**: _Sets the `--no-cache` flag on the `docker build` command._

#### **Additional Args**
Additional build args or flags to pass to `docker build` command.

#### **Examples**

```bash
# Example 1
$ bin/build.sh
# Example 2
$ bin/build.sh -N
# Example 3
$ bin/build.sh -F -N
```

### **Run**
Run a new project, or rerun an existing. Initial handling of aws init happens at shell (_~/.bashrc_).

```bash
$ bin/run.sh
```

#### **Advanced Run**
Interactive Run. Meant for quick debugging. The container will be removed after exit. Initial handling of aws init happens in entrypoint.

```bash
$ sh -c "$(cat bin/run.sh)"
```

**Usage**
```bash
usage:  run.sh -u <user> -t <team_name> -n <full_name> -m <email> -e <editor>
        run.sh --user <user> --team <team_name> --name <full_name> --email <email> --editor <editor>
```

## **Detailed Overview**

### **Project Structure**
(`tree --dirsfirst --charset=ascii`)

```
.
+-- bin/
|   |-- _resetter.sh
|   |-- build.sh
|   |-- package.sh
|   |-- package-cct.sh
|   |-- reboot.sh
|   |-- reset.sh
|   |-- run.sh
|   `-- zip2tgz.sh
+-- conf/
|   |   +-- base/
|   |       |-- docker-base.env
|   |       `-- versions-base.env
|   |   +-- main/
|   |       |-- defaults.env
|   |       |-- docker.env
|   |       `-- versions.env
|   |   +-- shared/
|   |       |-- docker-shared.env
|   |       `-- project.env
|   `-- env.sample
+-- dist/ # Only created if package script is run
+-- docker/
|   +-- addons/
|   |   +-- blank/
|   |       `-- blank.tgz
|   |   +-- <package-group>/
|   |       `-- <package-name>.zip
|   +-- bin/
|   |   |-- docker-entrypoint.sh
|   |   |-- init.sh
|   |   |-- mytf.sh
|   |   `-- wtf
|   +-- conf/
|   |   +-- vscode/
|   |       `-- launch.json
|   +-- dockerfiles/
|   |   |-- Dockerfile.base
|   |   `-- Dockerfile.main
|   +-- docs/
|   |   `-- README.md
|   +-- opt/
|   |   `-- describe
|   +-- profile/
|   |   |-- 10-colors.sh
|   |   |-- 20-aws-prompt.sh
|   |   |-- 20-kube-prompt.sh
|   |   |-- 41-misc-aliases.sh
|   |   |-- 80-platform-functions.sh
|   |   |-- 81-platform-aliases.sh
|   |   `-- 99-prompt.sh
+-- mount/ # Only created after first run
|   +-- addons/
|   +-- data/
|   +-- home/
|       +-- root/
|           +-- .aws/
|               `-- [files]
|           +-- .dpctl/
|               `-- [files]
|           +-- .kube/
|               `-- [files]
|           +-- .ssh/
|               `-- [files]
`-- README.md
```

### **File Persistence**

#### **Standard data**

* mount/home/root/.aws:/root/.aws
* mount/home/root/.kube:/root/.kube
* mount/home/root/.dpctl:/root/.dpctl
* mount/home/root/.ssh:/root/.ssh
* mount/data:/data
* mount/addons:/tmp/addons

#### **Password data**

**_{mountpoint}_** -- _/var/lib/docker/volumes/**{randomstr}**/\_data_

**_{randomstr}_** -- a random string being generated in the run.sh script

* {mountpoint}/.awsvault:/root/.awsvault"
* {mountpoint}/.gnupg:/root/.gnupg"
* {mountpoint}/.password-store:/root/.password-store"

#### **Docker-in-Docker**
* /var/run/docker.sock:/var/run/docker.sock
