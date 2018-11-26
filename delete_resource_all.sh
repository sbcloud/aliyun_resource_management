#!/bin/bash
#
# 2018/08 created by Qiu
# -----------------------------------------------
# Description:
#  To delete the following resouces on Alibaba Cloud
#    vpn_connection, customer_gateway, vpn_gateway
#    ecs_instance, ecs_image, snapshot, security_group
#    db_instance, vswitch, vpc, slb, access_key(ram user), oss_buckets, eip
#
# Usage:
#  $ ./delete_resource.sh <region> <role_arn>
#
# Params:
#  <region>   : 例 ap-northeast-1
#  <role_arn> : AssumeRole ARN
#
# -----------------------------------------------

declare assume_role_info
declare -A CMD

params=$#
input_region=$1
role_arn=$2


# ====================================================
# Usage
# ====================================================
function usage() {
cat <<_EOT_

Usage:
  $ $0 <region> <role_arn>

Params:
  <region>  : ap-northeast-1
  <role_arn>: acs:ram::5644******921:role/sts_test

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
# For checking the region inputed
# ====================================================
function containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# ====================================================
# Check the region inputed
# ====================================================
function check_region () {
  _regions=`aliyun ecs DescribeRegions | jq -r ".Regions.Region[].RegionId"`
  containsElement $1 ${_regions[@]}
  if [ $? != 0 ]; then
    echo "Incorrect region inputed : [ $1 ] !"
    echo "Select a region in the following."
    echo "------------------------------------"
    i=1
    for region in ${_regions[@]}; do
      echo ${i}: ${region}
      let i++
    done
    echo "------------------------------------"
  fi
  return 0
}


# ====================================================
# Set AssumeRole info
# ====================================================
function assume_role() {

  local _response
  local _access_key_id
  local _access_key_secret
  local _security_token

  _role_arn=$1

  _response=`aliyun sts AssumeRole --RoleArn ${_role_arn} --RoleSessionName "training" || throws_error`
  _access_key_id=`echo ${_response} | jq -r ".Credentials.AccessKeyId"`
  _access_key_secret=`echo ${_response} | jq -r ".Credentials.AccessKeySecret"`
  _security_token=`echo ${_response} | jq -r ".Credentials.SecurityToken"`

  # global: assume_role_info
  assume_role_info="--access-key-id ${_access_key_id} --access-key-secret ${_access_key_secret} --sts-token ${_security_token} --region ${input_region}"
  return 0
}


# ====================================================
# Delete target resource
# ====================================================
function delete_resource () {
  # $0 : shell process
  # $1 : service name
  # $2 ~ : resource_info

  echo "=============== delete_resource ${1} ==============="
  declare -A resource_info
  resource_info=${@:2}

  #TODO resource_infoが空き配列の場合の処理

  echo "------------------------------------------"
  echo "下記のコマンドが実行されました"
  for resource in ${resource_info[@]}; do
      # 例: aliyun ecs DeleteSnapshot --SnapshotId ${resource}
      echo ${CMD["$1"]} ${resource}
      ${CMD["$1"]} ${resource} || throws_error
      echo "実行完了!"
  done
  echo "------------------------------------------"

  return 0
}

# ====================================================
# Detach policy from user
# ====================================================
function delete_keys () {
  # $0 : shell process
  # $1 : service name
  # $2 ~ : ram user

  echo "=============== delete_keys ${1} ==============="
  declare -A user_info
  user_info=${@:1}

  echo "------------------------------------------"
  echo "下記のコマンドが実行されました"
  for user in ${user_info[@]}; do

      # access_key削除
      _access_keys=`aliyun ram ListAccessKeys ${assume_role_info} --UserName ${user} | jq -r ".AccessKeys.AccessKey[].AccessKeyId"`
      for access_key in ${_access_keys[@]}; do
        cmd="aliyun ram DeleteAccessKey ${assume_role_info} --UserName ${user} --UserAccessKeyId ${access_key}"
        echo ${cmd}
        ${cmd} || throws_error
      done

      echo "実行完了!"
  done
  echo "------------------------------------------"

  return 0
}


# ====================================================
# Delect OSS Bucket
# ====================================================
function delete_oss() {

  echo "=============== Delete OSS bucket & objects ==============="

  # OSS Bucket名の取得
  tmp=`aliyun oss ls ${assume_role_info} | awk -F ' ' '{print $7}'`
  oss_buckets=(`echo ${tmp}`)

  # OSS Bucketの削除
  for bucket in ${oss_buckets[@]}; do
    ###########[ Important Info] ###################################################
    # 下記の例のような object名にスペースが入っている場合
    # objectsをそのままechoすると、データがおかしくなるため
    # 一旦sedでスペースを「＊」に置き換え、【OSS Objectの削除】で 「＊」をスペースに戻す
    # [例]
    #  テスト結果 10 01.png → テスト結果*10*01.png → テスト結果 10 01.png
    #  ----------------------------------------
    ################################################################################
    tmp=`aliyun oss ls ${bucket} ${assume_role_info} | awk -F "${bucket}" '{print $2}' | sed 's/ /*/g'`
    objects=(`echo ${tmp}`)

    # OSS Objectの削除
    for object in ${objects[@]}; do
      ###########[ Important Info] #################################################
      # 下記の例のような object名にスペースが入っている場合
      # sedでスペースを「＊」に置き換えらたobject名をもとに戻す
      # [例]
      # テスト結果 10 01.png → テスト結果*10*01.png → テスト結果 10 01.png
      #                      ----------------------------------------
      #############################################################################
      object=`echo ${object} | sed 's/*/ /g'`
      aliyun oss rm "${bucket}${object}" ${assume_role_info}
    done

    delete_oss_bucket="aliyun oss rm -f -b ${bucket} ${assume_role_info}"
    echo "下記のコマンドが実行されました"
    echo ${delete_oss_bucket}
    ${delete_oss_bucket}
    echo "実行完了!"

  done

  echo "========================================="
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
# Start
# ====================================================

# params, regionの確認
check_params ${params}
check_region ${input_region}

# 対象アカウントのAssumeRole情報を取得
assume_role ${role_arn} || throws_error

# 対象リソース削除のコマンドの設定
CMD["vpn_connection"]="aliyun vpc DeleteVpnConnection ${assume_role_info} --VpnConnectionId "
CMD["customer_gateway"]="aliyun vpc DeleteCustomerGateway ${assume_role_info} --CustomerGatewayId "
CMD["vpn_gateway"]="aliyun vpc DeleteVpnGateway ${assume_role_info} --VpnGatewayId "
CMD["ecs_instance"]="aliyun ecs DeleteInstance --Force true ${assume_role_info} --InstanceId "
CMD["ecs_image"]="aliyun ecs DeleteImage --Force true ${assume_role_info} --ImageId"
CMD["snapshot"]="aliyun ecs DeleteSnapshot ${assume_role_info} --SnapshotId "
CMD["security_group"]="aliyun ecs DeleteSecurityGroup ${assume_role_info} --SecurityGroupId "
CMD["db_instance"]="aliyun rds DeleteDBInstance ${assume_role_info} --DBInstanceId "
CMD["vswitch"]="aliyun vpc DeleteVSwitch ${assume_role_info} --VSwitchId "
CMD["vpc"]="aliyun vpc DeleteVpc ${assume_role_info} --VpcId "
CMD["slb"]="aliyun slb DeleteLoadBalancer ${assume_role_info} --LoadBalancerId "
CMD["access_key"]="aliyun ram DeleteAccessKey ${assume_role_info} --UserAccessKeyId "
CMD["eip"]="aliyun vpc ReleaseEipAddress ${assume_role_info} --EipAddressesId "


#対象リソース情報取得
VpnConnectionIds=(`aliyun vpc DescribeVpnConnections ${assume_role_info} | jq -r ".VpnConnections.VpnConnection[].VpnConnectionId"`)
CustomerGatewayIds=(`aliyun vpc DescribeCustomerGateways ${assume_role_info} | jq -r ".CustomerGateways.CustomerGateway[].CustomerGatewayId"`)
VpnGateways=(`aliyun vpc DescribeVpnGateways ${assume_role_info} |
              jq  -r '.VpnGateways.VpnGateway[].VpnGatewayId | if .Status == "active" then .VpnGatewayId else empty end'`)
InstanceIds=(`aliyun ecs DescribeInstances ${assume_role_info} | jq -r '.Instances.Instance[].InstanceId'`)

ImageIds=(`aliyun ecs DescribeImages ${assume_role_info} |
                      jq -r '.Images.Image[] | if .ImageOwnerAlias == "self" then .ImageId else empty end'`)
SnapshotIds=(`aliyun ecs DescribeSnapshots ${assume_role_info} | jq -r '.Snapshots.Snapshot[].SnapshotId'`)
SecurityGroupIds=(`aliyun ecs DescribeSecurityGroups ${assume_role_info} | jq -r '.SecurityGroups.SecurityGroup[].SecurityGroupId'`)
DBInstanceIds=(`aliyun rds DescribeDBInstances ${assume_role_info} | jq -r '.Items.DBInstance[].DBInstanceId'`)
VSwitchIds=(`aliyun vpc DescribeVSwitches ${assume_role_info} | jq -r '.VSwitches.VSwitch[].VSwitchId'`)
VpcIds=(`aliyun vpc DescribeVpcs ${assume_role_info} | jq -r '.Vpcs.Vpc[] | if .IsDefault == false then .VpcId else empty end'`)
LoadBalancerIds=(`aliyun slb DescribeLoadBalancers ${assume_role_info} | jq -r '.LoadBalancers.LoadBalancer[].LoadBalancerId'`)
PoliciesForUser=(`aliyun ram ListPolicies | jq -r '.Policies.Policy[] | if .PolicyType == "Custom" then .PolicyName else empty end'`)
UserNames=(`aliyun ram ListUsers ${assume_role_info} | jq -r '.Users.User[].UserName'`)
EipAddressesIds=(`aliyun vpc DescribeEipAddresses ${assume_role_info} | jq -r ".EipAddresses.EipAddress[].EipAddressesId"`)


# --------------------------------------------------------------
# Delete the following resources
#    ecs_instance, ecs_image, snapshot, security_group
#    db_instance, vswitch, vpc, slb, user_name, oss_buckets
# --------------------------------------------------------------

# ------------------------------------------
# VpnConnection
# ------------------------------------------

if [ ${#VpnConnectionIds[@]} -eq 0 ]; then
  echo "[Info] No VpnConnectionIds!"
else
  delete_resource "vpn_connection" ${VpnConnectionIds[@]} || throws_error
fi

# ------------------------------------------z
# CustomerGateway
# ------------------------------------------
if [ ${#CustomerGatewayIds[@]} -eq 0 ]; then
  echo "[Info] No CustomerGatewayIds!"
else
  delete_resource "customer_gateway" ${CustomerGatewayIds[@]} || throws_error
fi

# ------------------------------------------
# VpnGateway
# ------------------------------------------
if [ ${#VpnGateways[@]} -eq 0 ]; then
  echo "[Info] No VpnGateways!"
else
  delete_resource "vpn_gateway" ${VpnGateways[@]} || throws_error
fi

# TODO:リファクタリング
flag=0
while [ ${flag} = 0 ]
do
  vpn_gateway=(`aliyun vpc DescribeVpnGateways ${assume_role_info} | jq  -r ".VpnGateways.VpnGateway[].VpnGatewayId"`)
  if [ ${#vpn_gateway[@]} -eq 0 ];then
    flag=1
  else
    echo "VpnGateway is deleting now, please wait!"
    sleep 5s
  fi
done

# ------------------------------------------
# ECS
# ------------------------------------------
# TODO
# instance削除後、DescribeInstancesでは取得できなくなるが、
# 裏ではしばらく残るため、security groupをすぐに削除できない
# 暫定対応: sleep 20s

if [ ${#InstanceIds[@]} -eq 0 ]; then
  echo "[Info] No InstanceIds!"
else
  delete_resource "ecs_instance" ${InstanceIds[@]} || throws_error
  sleep 20s
fi

# ------------------------------------------
# ECS Image
# ------------------------------------------
if [ ${#ImageIds[@]} -eq 0 ]; then
  echo "[Info] No ImageIds!"
else
  delete_resource "ecs_image" ${ImageIds[@]} || throws_error
fi

# ------------------------------------------
# ECS Snapshot
# ------------------------------------------
if [ ${#SnapshotIds[@]} -eq 0 ]; then
  echo "[Info] No SnapshotIds!"
else
  delete_resource "snapshot" ${SnapshotIds[@]} || throws_error
fi

# ------------------------------------------
# RDS
# ------------------------------------------
if [ ${#DBInstanceIds[@]} -eq 0 ]; then
  echo "[Info] No RDS DBinstance!"
else
  delete_resource "db_instance" ${DBInstanceIds} || throws_error
fi

# ------------------------------------------
# ECS Security Group
# ------------------------------------------
if [ ${#SecurityGroupIds[@]} -eq 0 ]; then
  echo "[Info] No SecurityGroupIds!"
else
  delete_resource "security_group" ${SecurityGroupIds[@]} || throws_error
fi


# ------------------------------------------
# VSwitch
# ------------------------------------------
if [ ${#VSwitchIds[@]} -eq 0 ]; then
  echo "[Info] No VSwitchIds!"
else
  delete_resource "vswitch" ${VSwitchIds[@]} || throws_error
fi

# ------------------------------------------
# VPC
# ------------------------------------------
if [ ${#VpcIds[@]} -eq 0 ]; then
  echo "[Info] No VpcIds!"
else
  delete_resource "vpc" ${VpcIds[@]} || throws_error
fi

# ------------------------------------------
# SLB
# ------------------------------------------
if [ ${#LoadBalancerIds[@]} -eq 0 ]; then
  echo "[Info] No LoadBalancerIds!"
else
  delete_resource "slb" ${LoadBalancerIds[@]} || throws_error
fi

# ------------------------------------------
# EIP Adresses
# ------------------------------------------
if [ ${#EipAddressesIds[@]} -eq 0 ]; then
  echo "[Info] No EIP Adresses!"
else
  delete_resource "eip" ${EipAddressesIds[@]} || throws_error
fi

# ------------------------------------------
# RAM Aceess Key
# ------------------------------------------
if [ ${#UserNames[@]} -eq 0 ]; then
  echo "[Info] No UserNames!"
else
  delete_keys ${UserNames[@]} || throws_error
fi

# ------------------------------------------
# Delete OSS Bucket
# ------------------------------------------
delete_oss || throws_error
