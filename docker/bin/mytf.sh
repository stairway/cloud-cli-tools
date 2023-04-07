#!/bin/sh -euf

# Adapted from https://gitlab.com/gitlab-org/terraform-images/-/blob/master/src/bin/gitlab-terraform.sh

export TF_PLAN_CACHE="${TF_PLAN_CACHE:-plan.cache}"
export TF_PLAN_JSON="${TF_PLAN_JSON:-plan.json}"

JQ_PLAN='
  (
    [.resource_changes[]?.change.actions?] | flatten
  ) | {
    "create":(map(select(.=="create")) | length),
    "update":(map(select(.=="update")) | length),
    "delete":(map(select(.=="delete")) | length)
  }
'

CCT_PROJECT_DIR="${CCT_PROJECT_ROOT:-/data}"
TF_BACKEND_CONFIG="${TF_BACKEND_CONFIG:-""}"
TF_INIT_FLAGS="${TF_INIT_FLAGS:-""}"
TF_ROOT="${TF_ROOT:-""}"
TF_CHDIR_OPT=""

# If TF_ROOT is set then use the -chdir option
if [ -n "${TF_ROOT}" ]; then
  abs_tf_root=$(cd "${CCT_PROJECT_ROOT}"; realpath "${TF_ROOT}")

  TF_CHDIR_OPT="-chdir=${abs_tf_root}"
fi

# Use terraform automation mode (will remove some verbose unneeded messages)
export TF_IN_AUTOMATION=true
export TF_CLI_ARGS_init='-input=false'
export TF_CLI_ARGS_plan='-input=false'
export TF_CLI_ARGS_apply='-auto-approve=true -input=false'
export TF_CLI_ARGS_destroy='-auto-approve=true -input=false'

init() {
  # We want to allow word splitting here for TF_INIT_FLAGS
  # shellcheck disable=SC2086
  if [ -n "${TF_INIT_FLAGS}" ]; then
    terraform "${TF_CHDIR_OPT}" init "${@}" -reconfigure ${TF_INIT_FLAGS}
  else
    terraform "${TF_CHDIR_OPT}" init "${@}" -reconfigure
  fi
}

for arg do
  shift
  case $arg in
    -backend-config=*|--backend-config=*)
      arg_val="$(echo $arg | awk -F'backend-config=' '{print $2}')"
      TF_INIT_FLAGS="${TF_INIT_FLAGS} -backend-config=${arg_val}"
      continue
      ;;
    *)
      set -- "$@" "$arg"
      ;;
  esac
done

case "${1}" in
  "apply")
    init
    terraform "${TF_CHDIR_OPT}" "${@}" "${TF_PLAN_CACHE}"
  ;;
  "destroy")
    init
    terraform "${TF_CHDIR_OPT}" "${@}"
  ;;
  "fmt")
    # https://www.terraform.io/cli/commands/fmt#check
    terraform "${TF_CHDIR_OPT}" "${@}" -check -diff -recursive
  ;;
  "init")
    # shift argument list "one to the left" to not call 'terraform init init'
    shift
    init "${@}"
  ;;
  "plan")
    init
    terraform "${TF_CHDIR_OPT}" "${@}" -out="${TF_PLAN_CACHE}"
  ;;
  "plan-json")
    terraform "${TF_CHDIR_OPT}" show -json "${TF_PLAN_CACHE}" | jq -r "${JQ_PLAN}" > "${TF_PLAN_JSON}"
  ;;
  "validate")
    init -backend=false
    terraform "${TF_CHDIR_OPT}" "${@}"
  ;;
  *)
    terraform "${@}"
  ;;
esac
