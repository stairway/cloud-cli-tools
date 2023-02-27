#!/usr/bin/env sh

set -euf

if [ $# -lt 2 ]; then
    echo "Usage: [src] [dest]"
    exit 1
fi

function realpath() (
    file=
    path=$1
    [ -d "$path" ] || {
        file=/$(basename -- "$path")
        path=$(dirname -- "$path")
    }
    {
        path=$(cd -- "$path" && pwd)$file
    } || exit $?
    printf %s\\n "/${path#"${path%%[!/]*}"}"
)

src="$(realpath $1)"
dest="$(realpath $2)"

printf "\033[93m>\033[0m %s ...\n" "Converting"
printf "  \033[97m-   %s\033[0m\n" "$src"
printf "  \033[97m=>  %s\033[0m\n" "${dest}.tgz"

tmp="$(mktemp -d)"
printf "\033[2;3m> Using temp dir %s\033[0m\n" "$tmp"
function cleanup() {
    printf "\033[93m>\033[0m %s ...\n" "Cleaning up"
    rm -rf $tmp
    printf "\033[92m>\033[0m \033[92;1m%s\033[0m\n" "Done"
}
trap cleanup INT TERM EXIT

unzip -q $src -d $tmp
chmod -R +r $tmp
tar -c -z -f "${dest}.tgz" -C $tmp .
