#!/usr/bin/env bash

# Função para adicionar cores no output das mensagens
# Exemplo: alerta r "Alguma mensagem de erro"

alerta() {
  local code="\033["
  local topo
  case "$1" in
    black    | bk) color="${code}0;30m";;
    error    |  r) color="${code}1;31m";;
    sucesso  |  g) color="${code}1;32m";;
    warning  |  y) color="${code}1;33m";;
    blue     |  b) color="${code}1;34m";;
    purple   |  p) color="${code}1;35m";;
    info     |  i) color="${code}0;37m";;
    topo     |  t) color="${code}0;30m"; topo="true";;
    *) local text="$1"
  esac
  [ -z "$text" ] && local text="$color$2${code}0m"
  [ -n "$topo" ] && printf "################### ${text} ########################\n"
  [ -z "$topo" ] && printf "$text\n"
}
