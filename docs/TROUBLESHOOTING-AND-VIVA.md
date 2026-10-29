# Troubleshooting and viva answers

Check in this order: instance state, destination IP, subnet route table, security rule.

| Symptom | What to inspect |
|---|---|
| Bastion SSH times out | Bastion public IP (it changes after stop/start - rerun `generate-ssh-config.sh --install`); your current public IP /32 in `ewb-sg-bastion` (it changes when you switch network); public subnet association; 0.0.0.0/0 route to the attached IGW |
| App-A SSH fails | App-A private IP; TCP 22 allowed from 10.10.1.10/32; correct key, `ec2-user`, instance running |
| App-B SSH fails | Public route table needs 10.20.0.0/16 -> pcx; VPC B needs the return route; App-B SSH source is the bastion private IP |
| Ping fails after acceptance | Both private route tables; correct pcx ID and Active state; Echo request rule on the destination; actual host IPs |
| Peering creation fails | Check every CIDR on both VPCs for overlap, including secondary CIDRs |
| Permission denied (publickey) | Correct key pair, local `IdentityFile`, `ec2-user`. Routing works if you reached SSH authentication |
| Failure with custom ACLs | Check both directions, ICMP rules and SSH return ephemeral ports. This lab assumes default allow-all ACLs |
| `Host key verification failed` in a script | Connect once by hand (`ssh ewb-app-a`, later `ssh ewb-app-b`) and verify the fingerprint |
| `terraform apply` says key pair not found | Run `scripts/create-key-pair.sh` first, in the same Region |

## Be ready to explain

**1. Why is the return route needed?**
A peering connection does not add routes. App-B's reply is addressed to 10.10.2.10, and VPC B only knows its
own 10.20.0.0/16 range until `ewb-rt-b-private` gets 10.10.0.0/16 -> pcx. Without it the request arrives but the
reply is dropped, so ping times out. Routing must exist in both directions.

**2. Why is the App-B SSH source the bastion private IP?**
With ProxyJump the laptop connects to the bastion, and the bastion opens a new TCP connection to App-B.
App-B therefore sees 10.10.1.10 as the source. Peering keeps private addresses (no NAT), so the rule is
10.10.1.10/32, not the laptop's public IP.

**3. Why does Active peering not guarantee a successful ping?**
Active only means the link exists. Traffic also needs a route in each subnet's route table, a security group rule on
the destination (and a custom NACL, if used) that allows it, and the correct private IPs.

**4. Can VPC B use VPC A's internet gateway over peering?**
No. Peering is one-to-one and non-transitive: it carries traffic between the two VPCs' own addresses only. It does not
let VPC B use A's internet gateway, NAT or VPN. VPC B has no internet gateway and no 0.0.0.0/0 route.

**Core concepts.** A-B plus A-C does not create B-C connectivity. An accepted connection can be deleted, but changing
which VPCs are paired needs a new connection. Routes and security rules stay configurable.
