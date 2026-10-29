# Evidence checklist (feeds the PDF report)

`python3 report/build_report.py` looks for these exact names. Items marked *required* are counted as
missing in the report until they exist. Never include private keys, access keys or tokens.

## Text logs in `evidence/logs/` (written by the scripts)
| File | Created by | Required |
|---|---|---|
| `00a-inventory-before-peering.txt` | `collect-inventory.sh before` | yes |
| `00b-inventory-after-peering.txt` | `collect-inventory.sh after` | yes |
| `01-baseline.txt` | `run-tests.sh baseline` | yes |
| `02-forward-path.txt` | `run-tests.sh forward` | yes |
| `03-reverse-path.txt` | `run-tests.sh reverse` | yes |
| `04-private-ssh.txt` | `run-tests.sh ssh` | yes |
| `05-isolation.txt` | `run-tests.sh isolation` | yes |
| `06-controlled-failure.txt` | `controlled-failure.sh` | yes |
| `07-cleanup.txt` | `cleanup-check.sh` | yes |

Also `evidence/terraform-outputs.json` (from `collect-inventory.sh`) supplies the resource IDs.

## Screenshots in `evidence/screenshots/` (png, jpg or jpeg; extension is optional in the name below)
| File name (stem) | What to capture | Required |
|---|---|---|
| `s01a-subnet-associations` | Subnet associations of `ewb-rt-a-public` and `ewb-rt-a-private` (Checkpoint 01) | yes |
| `s01b-public-default-route` | `ewb-rt-a-public` routes showing 0.0.0.0/0 to `ewb-igw-a` | yes |
| `s01c-private-rt-local-only` | `ewb-rt-a-private` with only its local route, before peering | yes |
| `s02-instances` | EC2 list: IDs, private IPs, bastion public IPv4, state (Checkpoint 02) | yes |
| `s03-peering-active` | `ewb-a-b-peer` Active with both VPC IDs and CIDRs (Checkpoint 03) | yes |
| `s04a-rt-a-private-routes` | `ewb-rt-a-private` routes + association (Checkpoint 04) | yes |
| `s04b-rt-b-private-routes` | `ewb-rt-b-private` routes + association | yes |
| `s04c-rt-a-public-routes` | `ewb-rt-a-public` routes + association | yes |
| `s05a-sg-bastion-inbound` | `ewb-sg-bastion` inbound rules | yes |
| `s05b-sg-app-a-inbound` | `ewb-sg-app-a` inbound rules | yes |
| `s05c-sg-app-b-inbound` | `ewb-sg-app-b` inbound rules | yes |
| `s06a-app-a-no-public-ip` | App-A instance details, Public IPv4 empty | yes |
| `s06b-app-b-no-public-ip` | App-B instance details, Public IPv4 empty | yes |
| `s07-sg-app-b-icmp-removed` | `ewb-sg-app-b` while the ICMP rule is removed | optional |
| `s08-cleanup-console` | Console filtered by the project tag showing nothing left | optional |

Label every screenshot with the host, test and result (the report builder adds a caption automatically).
