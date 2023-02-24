## Help
docker run \
    --platform linux/amd64 \
    --network=host \
    <image>:<tag> \
    describe

## Interactive
docker run \
    --rm \
    --platform linux/amd64 \
    --network=host \
    --name <instance-name> \
    -e KEEP_ALIVE=<true|false> \
    -e RACFID=<racfid> \
    -e TEAM_NAME=<team-name> \
    -e GIT_CONFIG_EMAIL="<email>" \
    -e GIT_CONFIG_FULL_NAME="<First-Name Last-Name>" \
    -e EDITOR=<nano|vim> \
    -v /var/lib/docker/volumes/<instance-name>/_data/.awsvault:/root/.awsvault \
    -v /var/lib/docker/volumes/<instance-name>/_data/.gnupg:/root/.gnupg \
    -v /var/lib/docker/volumes/<instance-name>/_data/.password-store:/root/.password-store \
    -v ${PWD}/mount/dotfiles/root/.aws:/root/.aws \
    -v ${PWD}/mount/dotfiles/root/.kube:/root/.kube \
    -v ${PWD}/mount/dotfiles/root/.dpctl:/root/.dpctl \
    -v ${PWD}/mount/dotfiles/root/.ssh:/root/.ssh \
    -v ${PWD}/cloud-cli-tools/mount/data:/data \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -it \
    <image>:<tag> \
    init.sh

## Daeomonized
docker run \
    --rm \
    --platform linux/amd64 \
    --network=host \
    --name <instance-name> \
    -e KEEP_ALIVE=<true|false> \
    -e RACFID=<racfid> \
    -e TEAM_NAME=<team-name> \
    -e GIT_CONFIG_EMAIL="<email>" \
    -e GIT_CONFIG_FULL_NAME="<First-Name Last-Name>" \
    -e EDITOR=<nano|vim> \
    -v /var/lib/docker/volumes/<instance-name>/_data/.awsvault:/root/.awsvault \
    -v /var/lib/docker/volumes/<instance-name>/_data/.gnupg:/root/.gnupg \
    -v /var/lib/docker/volumes/<instance-name>/_data/.password-store:/root/.password-store \
    -v ${PWD}/mount/dotfiles/root/.aws:/root/.aws \
    -v ${PWD}/mount/dotfiles/root/.kube:/root/.kube \
    -v ${PWD}/mount/dotfiles/root/.dpctl:/root/.dpctl \
    -v ${PWD}/mount/dotfiles/root/.ssh:/root/.ssh \
    -v ${PWD}/cloud-cli-tools/mount/data:/data \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -d \
    <image>:<tag>
