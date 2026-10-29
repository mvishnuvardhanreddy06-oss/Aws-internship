# Building the lab by hand in the AWS console

Terraform builds the same result, but if you want to follow the workbook click by click (or
re-create a screenshot) use this. Do not mix console edits with Terraform on the same resources.

Use one Region (for example ap-south-1) for everything.

## Network (workbook pp.5-6)
1. **Your VPCs > Create VPC > VPC only**: `ewb-vpc-a`, 10.10.0.0/16, no IPv6, tenancy Default.
2. **Subnets**: `ewb-a-public` 10.10.1.0/24 and `ewb-a-private` 10.10.2.0/24 in VPC A, same Availability Zone.
3. **Internet gateways**: create `ewb-igw-a`, Actions > Attach to a VPC > `ewb-vpc-a`.
4. **Route tables**: `ewb-rt-a-public` in VPC A, associate `ewb-a-public` explicitly, add `0.0.0.0/0` to `ewb-igw-a`.
5. `ewb-rt-a-private` in VPC A, associate `ewb-a-private`, local route only. Keep auto-assign public IPv4 off.
6. **Checkpoint 01** screenshots: subnet associations, public default route, private table with only the local route.
7. VPC B: `ewb-vpc-b` 10.20.0.0/16, `ewb-b-private` 10.20.1.0/24, `ewb-rt-b-private` associated explicitly. No internet gateway.
8. **Security groups** (inbound rules from `ARCHITECTURE.md`): `ewb-sg-bastion`, `ewb-sg-app-a` in VPC A and `ewb-sg-app-b` in VPC B.
   The CIDR goes in *Source*, never in *Port*. For Echo request choose Custom ICMP - IPv4 (type 8, code 0).

## Instances (workbook p.7)
1. EC2 > Key pairs > create RSA key pair `ewb-lab`, download the `.pem`, keep it on your laptop only.
2. Launch Amazon Linux 2023, t3.micro (or the type your instructor approves), small root disk with delete-on-termination.
3. Network settings > Edit: choose the VPC, subnet, existing security group, and in advanced network
   interface settings set the primary private IPv4:
   - `ewb-bastion`: ewb-a-public, 10.10.1.10, auto-assign public IP **Enable**
   - `ewb-app-a`: ewb-a-private, 10.10.2.10, auto-assign public IP **Disable**
   - `ewb-app-b`: ewb-b-private, 10.20.1.10, auto-assign public IP **Disable**
4. Wait for 2/2 status checks. **Checkpoint 02** screenshot: IDs, private IPs, bastion public IPv4, empty public IPv4 for App-A and App-B.

## SSH and baseline (workbook p.8)
`chmod 400 ~/.ssh/ewb-lab.pem`, add the three `Host` blocks from `scripts/generate-ssh-config.sh`, then
`ssh ewb-bastion`, `exit`, `ssh ewb-app-a`, and inside App-A run `ping -c 4 10.20.1.10` (no replies expected).

## Peering and routes (workbook pp.9-10)
1. **Peering connections > Create**: name `ewb-a-b-peer`, requester `ewb-vpc-a`, My account, This Region, accepter `ewb-vpc-b`.
2. Actions > **Accept request** (required even in one account). Wait for **Active**. **Checkpoint 03** screenshot.
3. Add routes: `ewb-rt-a-private` 10.20.0.0/16 -> pcx; `ewb-rt-b-private` 10.10.0.0/16 -> pcx; `ewb-rt-a-public` 10.20.0.0/16 -> pcx.
4. **Checkpoint 04** screenshots of all three tables and their subnet associations.

## Cleanup (workbook p.14)
Terminate the three instances, confirm volumes are gone, delete the peer routes and `ewb-a-b-peer`, delete security
groups, subnets, custom route tables, detach and delete `ewb-igw-a`, delete both VPCs, delete the key pair.
Then filter by `Project = EWB-VPC-Peering` in EC2, Volumes and VPC to confirm nothing is left.
