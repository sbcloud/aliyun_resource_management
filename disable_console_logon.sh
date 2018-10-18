#!/bin/bash
#
# 2018/09 created by Qiu
# -----------------------------------------------
# Description:
#
# Usage:
#  $ ./disable_consle_logon
#
# Params:
#  なし
#
# -----------------------------------------------

# 対象RAMユーザー(handson**)の指定
TARGET="handson"

# ====================================================
# Usage
# ====================================================
function usage() {
cat <<_EOT_
Usage:
  $ $0

Params:
  なし

_EOT_
exit 1
}

# ====================================================
# Check params
# ====================================================
function check_params () {
  if [ $1 != 1 ]; then
    usage
  fi
  return 0
}

# ====================================================
# RAMユーザーのコンソール利用の無効化
# ====================================================
function disable_consle_logon() {
  _keyword=$1
  _users=`aliyun ram ListUsers | jq -r ".Users.User[].UserName" | grep ${_keyword}`

  for user in ${_users[@]}; do
    aliyun ram DeleteLoginProfile --UserName ${user}
  done
}

# ====================================================
# error logic
# ====================================================
function throws_error() {
  echo "Failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1
}


# ====================================================
# コンソールログオン無効化処理開始
# ====================================================

# paramsの確認

disable_consle_logon ${TARGET} || throws_error
