# Requirments

* bash 4.4
* jq
* [aliyun cli](https://github.com/aliyun/aliyun-cli)

# Usage

<1> $ ./delete_resource_all.sh [region] [role_arn]

下記リソースの削除
    vpn_connection, customer_gateway, vpn_gateway
    ecs_instance, ecs_image, snapshot, security_group
    db_instance, vswitch, vpc, slb, user_name(ram user), oss_buckets

```
Params:
  <region>   : 例 ap-northeast-1
  <role_arn> : AssumeRole ARN
```  

<2> $ ./disable_consle_logon.sh

RAMユーザのコンソールログオンの無効化

```
Params:
  なし
```

<3> $ ./enable_console_logon.sh <target> <password>
RAMユーザのコンソールログオンの有効化

```
Params:
  <target>   : 対象RAM Userが共通となる文字列
  <password> : パスワード
               複数パスワードの場合は「,」で連結された文字列
```
