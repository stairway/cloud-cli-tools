# Cloud CLI Tools - Usage

## Help
```bash
docker run {image}:{tag} describe
```

## Interactive
```bash
docker run \
    --rm \
    --platform {linux/amd64|linux/arm64} \
    --name {instance-name} \
    -p 5678:5678 \
    -e KEEP_ALIVE={true|false} \
    -e USERNAME={user} \
    -e TEAM_NAME={team-name} \
    -e CLUSTER_PREFIX={cluster-prefix} \
    -e EDITOR={nano|vim} \
    -e VSCODE_DEBUGPY_PORT=5678 \
    -e DEFAULT_PROFILE={default-profile (user)} \
    -e AWS_VAULT_USER_REGION={aws-region} \
    -e GIT_CONFIG_FULL_NAME="{First-Name Last-Name}" \
    -e GIT_CONFIG_EMAIL="{email}" \
    -e HISTFILE="{histfile (/root/.bash_history)}"
    -e TERM={term (xterm-256color)} \
    -e UNAME={root|ubuntu} \
    -v /var/lib/docker/volumes/{instance-name}/_data/.awsvault:/{uname home}/.awsvault \
    -v /var/lib/docker/volumes/{instance-name}/_data/.gnupg:/{uname home}/.gnupg \
    -v /var/lib/docker/volumes/{instance-name}/_data/.password-store:/{uname home}/.password-store \
    -v ${PWD}/mount/home/{uname}/.bash_history:/{uname home}/.bash_history \
    -v ${PWD}/mount/home/{uname}/.env:/{uname home}/.local/.env \
    -v ${PWD}/mount/home/{uname}/.aws:/{uname home}/.aws \
    -v ${PWD}/mount/home/{uname}/.kube:/{uname home}/.kube \
    -v ${PWD}/mount/home/{uname}/.dpctl:/{uname home}/.dpctl \
    -v ${PWD}/mount/home/{uname}/.ssh:/{uname home}/.ssh \
    -v ${PWD}/mount/data:/data \
    -v ${PWD}/mount/addons:/tmp/addons \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -it \
    {image}:{tag}
```

## Daeomonized
```bash
docker run \
    --rm \
    --platform {linux/amd64|linux/arm64} \
    --name {instance-name} \
    -p 5678:5678 \
    -e KEEP_ALIVE={true|false} \
    -e USERNAME={user} \
    -e TEAM_NAME={team-name} \
    -e CLUSTER_PREFIX={cluster-prefix} \
    -e EDITOR={nano|vim} \
    -e VSCODE_DEBUGPY_PORT=5678 \
    -e DEFAULT_PROFILE={default-profile (user)} \
    -e AWS_VAULT_USER_REGION={aws-region} \
    -e GIT_CONFIG_FULL_NAME="{First-Name Last-Name}" \
    -e GIT_CONFIG_EMAIL="{email}" \
    -e HISTFILE="{histfile (/root/.bash_history)}"
    -e TERM={term (xterm-256color)} \
    -e UNAME={root|ubuntu} \
    -v /var/lib/docker/volumes/{instance-name}/_data/.awsvault:/{uname home}/.awsvault \
    -v /var/lib/docker/volumes/{instance-name}/_data/.gnupg:/{uname home}/.gnupg \
    -v /var/lib/docker/volumes/{instance-name}/_data/.password-store:/{uname home}/.password-store \
    -v ${PWD}/mount/home/{uname}/.bash_history:/{uname home}/.bash_history \
    -v ${PWD}/mount/home/{uname}/.env:/{uname home}/.local/.env \
    -v ${PWD}/mount/home/{uname}/.aws:/{uname home}/.aws \
    -v ${PWD}/mount/home/{uname}/.kube:/{uname home}/.kube \
    -v ${PWD}/mount/home/{uname}/.dpctl:/{uname home}/.dpctl \
    -v ${PWD}/mount/home/{uname}/.ssh:/{uname home}/.ssh \
    -v ${PWD}/mount/data:/data \
    -v ${PWD}/mount/addons:/tmp/addons \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -d \
    {image}:{tag}
```
