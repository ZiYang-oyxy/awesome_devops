export PUTURL="http://Awesome:Devops@10.145.17.12:8889"
export GETURL="http://Awesome:Devops@10.145.17.12:8890"

cecho() {
  local code="\033["
  case "$1" in
    black  | bk) color="${code}0;30m";;
    red    |  r) color="${code}0;31m";;
    green  |  g) color="${code}0;32m";;
    yellow |  y) color="${code}0;33m";;
    blue   |  b) color="${code}0;34m";;
    purple |  p) color="${code}0;35m";;
    cyan   |  c) color="${code}0;36m";;
    gray   | gr) color="${code}0;30m";;
    *) local text="$1"
  esac
  [ -z "$text" ] && local text="$color$2${code}0m"
  echo -e "$text"
}

cecho_test() {
	ret="test"
	cecho bk "$ret"
	cecho r "$ret"
	cecho g "$ret"
	cecho y "$ret"
	cecho b "$ret"
	cecho p "$ret"
	cecho c "$ret"
	cecho gr "$ret"
}

curdir(){
    dirname $(readlink -f $0)
}
