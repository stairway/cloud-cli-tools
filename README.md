# Cloud CLI Tools

## **TLDR;**
**Clone/Build/Run**

```bash
git clone git@github.com:stairway/cloud-cli-tools.git && \
    cd cloud-cli-tools && bin/build.sh -F && sh -c "$(cat bin/run.sh)"
```

## **Table of Contents**

1. [Summary](#summary)
1. [Pre-Requisites](#pre-requisites)
   1. [Required Dependencies](#required-dependencies)
1. [Setup Instructions](#setup-instructions)
   1. [Initial Setup](#initial-setup)
      1. [Step 1 - Extract](#step-1-extract)
      1. [Step 2 - First Build](#step-2-first-build)
   1. [Run Instructions](#run-instructions)
      1. [Step 3 - Run](#step-3-run)
1. [Command Overview](#command-overview)
   1. [Reset](#reset)
   1. [Build](#build)
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

#### **\*IMPORTANT (Especially for M1 users)\***
If you're having trouble building, check if you have Experimental Features enabled in the Settings for Docker Desktop. If it's enabled, then disable it.

## **Setup Instructions**
3 easy steps: extract, build, run

### **Initial Setup**

#### **Step 1: Extract**

```bash
$ tar -xzf cloud-cli-tools.tgz
$ cd cloud-cli-tools
```

#### **Step 2: First Build**

```bash
$ bin/build.sh -F
```

### **Run Instructions**

#### **Step 3: Run**

```bash
$ bin/run.sh
```

## **Command Overview**

### **Reset**
2 types of reset: **_quick_** and **_full_**

_Usage:_
```
bin/reset.sh
bin/reset.sh [OPTIONS]
```

#### **Options**

**`No Flags` -- `bin/reset.sh`**: _**Quick** mode. Destroys container. All other persisted files will remain untouched._

**`-F|--full`**: _**Full** mode. Destroys container and persisted dotfiles (~/.ssh folder will remain untouched)_

#### **Examples**

```bash
# Example 1
$ bin/reset.sh
# Example 2
$ bin/reset.sh -F
```

### **Build**
2 types of build: **_quick_** and **_full_**

_Usage:_
```
bin/build.sh
bin/build.sh [OPTIONS] [ADDITIONAL_ARGS]
```

#### **Options**

**`No Flags` -- `bin/build.sh`**: _**Quick** mode. Quick rebuild. Does not build parent image, so quick builds are not intended for the [first build](#step-2-first-build)_

**`-F|--full`**: _Full (deep) build. Required for first build. Builds all necessary images._

**`-N|--no-cache`**: _Sets the `--no-cache` flag on the `docker build` command._

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
usage:  run.sh -u <racfid> -t <team_name> -n <full_name> -m <email> -e <editor>
        run.sh --racfid <racfid> --team <team_name> --name <full_name> --email <email> --editor <editor>
```

## **Detailed Overview**

### **Project Structure**
(`tree --dirsfirst --charset=ascii`)

```
.
+-- bin/
|   |-- build.sh
|   |-- package.sh
|   |-- reset.sh
|   `-- run.sh
+-- conf/
|   |-- defaults.env
|   |-- docker.env
|   |-- vars.env
|   `-- versions.env
+-- docker/
|   +-- bin/
|   |   |-- docker-entrypoint.sh
|   |   |-- init.sh
|   |   `-- wtf
|   +-- dockerfile/
|   |   |-- base.Dockerfile
|   |   `-- main.Dockerfile
|   +-- dotfiles/
|   |   |-- .bashrc
|   |   |-- .platform_aliases
|   |   `-- .profile
|   +-- mount/ # Only created after first run
|   |   +-- data/
|   |   +-- dotfiles/
|   |       +-- root/
|   |           +-- .aws/
|   |               `-- [files]
|   |           +-- .dpctl/
|   |               `-- [files]
|   |           +-- .kube/
|   |               `-- [files]
|   |           +-- .aws/
|   |               `-- [files]
|   `-- dpctl-latest-linux-amd64.tgz
`-- README.md
```

### **File Persistence**

#### **Standard data**

* mount/dotfiles/root/.aws:/root/.aws"
* mount/dotfiles/root/.kube:/root/.kube"
* mount/dotfiles/root/.dpctl:/root/.dpctl"
* mount/dotfiles/root/.ssh:/root/.ssh"
* mount/data:/data"

#### **Password data**

**_{mountpoint}_** -- _/var/lib/docker/volumes/**{randomstr}**/\_data_
**_{randomstr}_** -- a random string being generated in the run.sh script

* {mountpoint}/.awsvault:/root/.awsvault"
* {mountpoint}/.gnupg:/root/.gnupg"
* {mountpoint}/.password-store:/root/.password-store"