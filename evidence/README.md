# Evidence folder

Everything the report needs goes here. **Only real output from your own run belongs in this folder.**

| Folder | What goes in it | Who creates it |
|---|---|---|
| `logs/` | Text evidence: inventory, route tables, security-group rules, test output, controlled failure, cleanup | The scripts in `scripts/` write these automatically |
| `screenshots/` | Console screenshots (Checkpoints 01-04, security-group rules, no-public-IP proof) | You, from the AWS console |
| `terraform-outputs.json` | Resource IDs for the report inventory | `scripts/collect-inventory.sh` |

The exact file names the report builder looks for are listed in `docs/EVIDENCE-CHECKLIST.md`.

Before committing: open every screenshot and check that no private key, access key, secret or
session token is visible. Crop or blur your AWS account ID if you do not want it public.
