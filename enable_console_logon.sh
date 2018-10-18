#!/bin/bash
#
# 2018/09 created by Qiu
# -----------------------------------------------
# Description:
#
# Usage:
#  $ ./enable_console_logon.sh <target> <password>
#
# Params:
#  <target>   : 対象RAM Userが共通となる文字列
#  <password> : パスワード
#               複数パスワードの場合は「,」で連結された文字列
#
# -----------------------------------------------

params=$#

# 対象RAMユーザー(handson**)の指定
TARGET=$1
PASSWORD=$2

# ====================================================
# Usage
# ====================================================
function usage() {
cat <<_EOT_

Usage:
  $ $0 <target> <password>

Params:
  <target>   : 対象RAM Userが共通となる文字列

  <password> : パスワード
               複数パスワードの場合は「,」で連結された文字列

_EOT_
exit 1
}

# ====================================================
# Check params
# ====================================================
function check_params () {
  if [ $1 != 2 ]; then
    usage
  fi
  return 0
}


# ====================================================
# RAMユーザーのコンソール利用の有効化
# ====================================================
function enable_consle_logon() {

  _keyword=$1

  #「,」で複数のPWを連結し、引数として渡す
  _password_array=(`echo ${2} | tr ',' ' '`)

  _users=(`aliyun ram ListUsers | jq -r ".Users.User[].UserName" | grep ${_keyword} | sort`)

  _user_num=${#_users[*]}
  if [ ${_user_num} -gt 0 ]; then
    # 対象RAM Userがある場合
    i=0
    for user in ${_users[@]}; do
      echo "-----------------"
      echo ${user}
      echo ${_password_array[i]}
      echo "-----------------"
      aliyun ram CreateLoginProfile --UserName ${user} --Password ${_password_array[i]}
      let i++
    done
  else
    # 対象RAM Userがない場合
    echo "[ Warning ] No Taget RAM User started with [ ${_keyword} ] !"
    exit 1
  fi

  return 0
}

# ====================================================
# error logic
# ====================================================
function throws_error() {
  echo "Failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1
}


# ====================================================
# コンソールログオン有効化処理開始
# ====================================================
check_params ${params}
enable_consle_logon ${TARGET} ${PASSWORD} || throws_error
