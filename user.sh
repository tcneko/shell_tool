#!/bin/bash

# author: tcneko <tcneko@outlook.com>
# start from: 2018.02
# last test environment: ubuntu 20.04
# description:

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

# variables
base_id_regular=10000
base_id_service=20000
max_offset=10000

base_id=${base_id_service}

opt_flag_regular_user=1

func_opt_list=(h r a d s)
func_opt_long_list=(help regular add delete show)

# function
echo_info() {
  echo -e "\e[1;32m[Info]\e[0m $@"
}

echo_warning() {
  echo >&2 -e "\e[1;33m[Warning]\e[0m $@"
}

echo_error() {
  echo >&2 -e "\e[1;31m[Error]\e[0m $@"
}

func_opt_init() {
  for func_opt_long in ${func_opt_long_list[@]}; do
    echo ${func_opt_long} | grep ":$" &>/dev/null
    if (($? != 0)); then
      flag_code=$(echo ${func_opt_long} | tr '-' '_')
      eval opt_flag_${flag_code}=1
    fi
  done
}

test_root_exit() {
  if (($(id -u) != 0)); then
    echo_error 'Please run as root'
    exit 1
  fi
}

test_command_exit() {
  for cmd in $@; do
    command -v ${cmd} &>/dev/null
    if (($? != 0)); then
      echo_error "Please install \"${cmd}\""
      exit 1
    fi
  done
}

help() {
  cat <<EOF

SYNOPSIS
  user.sh {-h | --help}
  user.sh {-a | --add} [-r | --regular-user] <USERNAME>
  user.sh {-d | --delete} <USERNAME>
  user.sh {-s | --show} [-r | --regular-user] <USERNAME>

OPTIONS
  -h, --help
      Show help information

  -a, --add
      Add user

  -d, --delete
      Delete user

  -s, --show
      Show user status

  -r, --regular-user
      Use with -a or -s, the user is a regular user instead of service user

EOF
}

calc_user_id() {
  id_hash=$(echo -n $1 | md5sum | tr -s " " | cut -d " " -f 1 | tr "a-z" "A-Z")
  id_offset=$(echo "ibase=16;s1=${id_hash};ibase=A;s1%${max_offset}" | bc)
  echo $((${base_id} + ${id_offset}))
}

add_user() {
  user_id=$(calc_user_id $@)

  # uid
  cat /etc/passwd | cut -d: -f3 | grep ${user_id} &>/dev/null
  if (($? == 0)); then
    echo_error 'UID already exists'
    exit 1
  fi
  # username
  cat /etc/passwd | cut -d: -f1 | grep -E "^$1$" &>/dev/null
  if (($? == 0)); then
    echo_error 'Username already exists'
    exit 1
  fi
  # gid
  cat /etc/group | cut -d: -f3 | grep ${user_id} &>/dev/null
  if (($? == 0)); then
    echo_error 'GID already exists'
    exit 1
  fi
  # groupname
  cat /etc/group | cut -d: -f1 | grep -E "^$1$" &>/dev/null
  if (($? == 0)); then
    echo_error 'Groupname already exists'
    exit 1
  fi

  groupadd -g ${user_id} $1
  if ((${opt_flag_regular_user} == 0)); then
    useradd -u ${user_id} -g ${user_id} -s /bin/bash -m $1
  else
    useradd -u ${user_id} -g ${user_id} -s /usr/sbin/nologin -M $1
  fi
}

del_user() {
  userdel -r $1
  if (($? != 0)); then
    echo_error 'Error occurred during the deletion'
    exit 1
  fi
}

show_user() {
  echo
  echo "Username: $1"
  user_id=$(calc_user_id $@)
  echo "UID: ${user_id}"
  echo
  # uid
  cat /etc/passwd | cut -d: -f3 | grep ${user_id} &>/dev/null
  if (($? == 0)); then
    echo "UID exist: true"
  else
    echo "UID exist: false"
  fi
  # username
  cat /etc/passwd | cut -d: -f1 | grep -E "^$1$" &>/dev/null
  if (($? == 0)); then
    echo "Username exist: true"
  else
    echo "Username exist: false"
  fi
  # gid
  cat /etc/group | cut -d: -f3 | grep ${user_id} &>/dev/null
  if (($? == 0)); then
    echo "GID exist: true"
  else
    echo "GID exist: false"
  fi
  # groupname
  cat /etc/group | cut -d: -f1 | grep -E "^$1$" &>/dev/null
  if (($? == 0)); then
    echo "Groupname exist: true"
  else
    echo "Groupname exist: false"
  fi
  echo
}

run_by_flag() {
  if ((${opt_flag_add} == 0)); then
    add_user $@
    return $?
  elif ((${opt_flag_delete} == 0)); then
    del_user $@
    return $?
  elif ((${opt_flag_show} == 0)); then
    show_user $@
    return 0
  fi
}

# main
test_root_exit
if (($? != 0)); then
  exit 1
fi

test_command_exit bc
if (($? != 0)); then
  exit 1
fi

func_opt_init

func_opt=$(echo ${func_opt_list[@]} | sed 's/ //g')
func_opt_long=$(echo ${func_opt_long_list[@]} | sed 's/ /,/g')
args_temp=$(getopt -o "${func_opt}" -l "${func_opt_long}" -- "$@")
if (($? != 0)); then
  echo_error 'Invalid option'
  exit 1
fi
eval set -- "${args_temp}"
while true; do
  case $1 in
    -h | --help)
      help
      exit 0
      ;;
    -r | --regular-user)
      base_id=${base_id_regular}
      opt_flag_regular_user=0
      ;;
    -a | --add)
      opt_flag_add=0
      ;;
    -d | --delete)
      opt_flag_delete=0
      ;;
    -s | --show)
      opt_flag_show=0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo 'Invalid option'
      exit 1
      ;;
  esac
  shift
done

run_by_flag $@

exit 0
