# Kubernetes context module

function zpe__kubectl_current_context() {
  command -v kubectl >/dev/null 2>&1 || return 1
  kubectl config current-context 2>/dev/null
}

function zpe__kubectl_namespace() {
  command -v kubectl >/dev/null 2>&1 || return 1
  kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null
}

function zpe_module_kubectl() {
  local ctx
  ctx=$(zpe__kubectl_current_context) || return
  [[ -z $ctx ]] && return

  local seg="k8s:${ctx}"
  if [[ ${ZPE_KUBE_CONF[show_namespace]} == true ]]; then
    local ns
    ns=$(zpe__kubectl_namespace)
    [[ -n $ns ]] && seg+="/${ns}"
  fi

  local color_prefix=$(zpe_color accent magenta)
  local color_reset="%f"
  print -n -- "${color_prefix}${seg}${color_reset}"
}
