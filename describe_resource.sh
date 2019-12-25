#!/bin/bash

# 対応プロダクト:  VPC(VPC,VSwitch,VPN,SSL-VPN,NAT,EIP), ECS, RDS, SLB, RAM

for r in `aliyun vpc DescribeRegions  | jq -r -c ".Regions.Region[].RegionId"`; do
  echo -n "#### Region: ";
  aliyun vpc DescribeRegions --AcceptLanguage ja | jq -r -c ".Regions.Region[] | select(.RegionId | test( \"$r\") ) |[.RegionId, .LocalName] "
  echo "### VPC";
  echo "## VPCs";
  aliyun vpc DescribeVpcs | jq -r -c ".Vpcs.Vpc[] | if .RegionId == \"$r\" then [.RegionId, .VpcId, .VpcName, .CidrBlock, .VSwitchIds[] ] else empty end"
  echo "## VSwitches";
  aliyun vpc DescribeVSwitches | jq -r -c ".VSwitches.VSwitch[] | select( .ZoneId | test(\"$r*\")) | [.ZoneId, .IsDefault, .Status, .VSwitchId, .VSwitchName, .CidrBlock,.AvailableIpAddressCount, .VpcId]  ";
  echo "### ECS"
  echo "## ECS Instances"
  aliyun --RegionId $r ecs DescribeInstances | jq -r -c ".Instances.Instance[] | [.Cpu, .Memory, .InstanceType, .OSType, .HostName, .RegionId]";
  echo "## ECS Disks"
  aliyun --RegionId $r ecs DescribeDisks | jq -r -c ".Disks.Disk[] | [.CreationTime, .Type, .Size, .Status, .DiskName]"
  echo "## Snapshots"
  aliyun --RegionId $r ecs DescribeSnapshots | jq -r -c '.Snapshots.Snapshot[] | [.SnapshotId, .SourceDiskSize, .Usage, .SnapshotName, .LastModifiedTime]'
  echo "## Images"
  aliyun --RegionId $r ecs DescribeImages | jq -r -c '.Images.Image[] | if .ImageOwnerAlias == "self" then [.ImageId, .ImageName, .Size, .Status,.Progress, .CreationTime] else empty end'
  echo "## SecurityGroupIds"
  aliyun --RegionId $r ecs DescribeSecurityGroups ${assume_role_info} | jq -r -c '.SecurityGroups.SecurityGroup[] | [.SecurityGroupId, .SecurityGroupName, .VpcId,.CreationTime]'
  echo "## ECS EipAddresses"
  aliyun --RegionId $r ecs DescribeEipAddresses | jq -r -c ".EipAddresses.EipAddress[] | [.RegionId, .Status, .IpAddress, .InstanceType, .InstanceId]"
  echo "## ECS KeyPair"
  aliyun --RegionId $r ecs DescribeKeyPairs | jq -r -c ".KeyPairs.KeyPair[] | [.CreationTime, .KeyPairName]"
  
  echo "### RDS";
  aliyun rds DescribeDBInstances  | jq -r -c ".Items.DBInstance[] | select( .RegionId | test(\"$r\")) | [.RegionId, .DBInstanceId, .DBInstanceType, .DBInstanceNetType, .ZoneId, .InstanceNetworkType, .VpcId, .VSwitchId, .CreateTime]";
  echo "### SLB";
  aliyun slb DescribeLoadBalancers  | jq -r -c ".LoadBalancers.LoadBalancer[] | select( .RegionId | test(\"$r\"))  | [.RegionId, .LoadBalancerId,.LoadBalancerStatus, .PayType, .NetworkType, .MasterZoneId, .SlaveZoneId, .Address,  .CreateTime]"
  
  echo "### VPN"
  aliyun --region $r vpc DescribeVpnConnections | jq -r -c ".VpnConnections.VpnConnection[] | [.VpnConnectionId, .VpnGatewayId, .CustomerGatewayId, .Status, .LocalSubnet, .RemoteSubnet ]"
  echo "## CustomerGateways"
  aliyun --region $r vpc DescribeCustomerGateways | jq -r -c ".CustomerGateways.CustomerGateway[] | [.CustomerGatewayId, .IpAddress, .Name]"
  echo "## VPN Gateways"
  aliyun --region $r vpc DescribeVpnGateways | jq  -r -c '.VpnGateways.VpnGateway[] | [.VpnGatewayId, .Status, .Name, .IpsecVpn, .SslVpn, .VpcId, .VSwitchId]'
done
echo "### Grobal"
echo "## RAMUsers"
aliyun ram ListUsers | jq -r -c '.Users.User[] | [.UserId, .UserName, .DisplayName, .CreateDate]'
echo "## RAMGroups"
aliyun ram ListGroups | jq -r -c ".Groups.Group[] | [.GroupName , .CreateDate]"
echo "## RAMUser"
aliyun ram ListPolicies | jq -r '.Policies.Policy[] | if .PolicyType == "Custom" then .PolicyName else empty end'

