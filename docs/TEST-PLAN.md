# Test plan (workbook page 11)

Expected results are acceptance criteria. Record real terminal output. The scripts save it to `evidence/logs/`.

| Test | Where / command | Expected result | Script | Log file |
|---|---|---|---|---|
| 01 Baseline | App-A, before peering: `ping -c 4 10.20.1.10` | No replies | `run-tests.sh baseline` | `01-baseline.txt` |
| 02 Forward path | App-A, after routes: `ping -c 4 10.20.1.10` | 4 replies, 0% loss | `run-tests.sh forward` | `02-forward-path.txt` |
| 03 Reverse path | App-B, after routes: `ping -c 4 10.10.2.10` | 4 replies, 0% loss | `run-tests.sh reverse` | `03-reverse-path.txt` |
| 04 Private SSH | Laptop: `ssh ewb-app-b` | Shell on App-B through bastion | `run-tests.sh ssh` | `04-private-ssh.txt` |
| 05 Isolation | EC2 instance details | No public IPv4 on App-A or App-B | `run-tests.sh isolation` | `05-isolation.txt` |
| Controlled failure | Remove only App-B's ICMP Echo rule, ping, restore, ping | Replies stop, then resume | `controlled-failure.sh` | `06-controlled-failure.txt` |

## Order of execution
1. Stage 1 (`enable_peering = false`): `terraform apply`, `wait-for-instances.sh`, `collect-inventory.sh before`,
   connect by hand once to the bastion and App-A (verify host keys), then `run-tests.sh baseline`.
2. Stage 2 (`enable_peering = true`): `terraform apply`, `collect-inventory.sh after`, connect by hand once to App-B,
   then `run-tests.sh after-peering`.
3. `controlled-failure.sh`.
4. `terraform destroy`, `delete-key-pair.sh`, `cleanup-check.sh`.

## Notes
- If the first ping run loses a packet while a host finishes booting, wait briefly and repeat.
- After the ICMP rule is removed, allow a few seconds before testing. The script waits 20 seconds.
- Keep the SSH rule in place during the controlled failure. The script proves SSH still works.
