# Ninja Scripts

This repository contains a small collection of scripts written to automate tasks within NinjaOne. Scripts are grouped by functional area where possible. They are provided as-is and can be used directly or customized to fit your environment.

## winget

This section contains scripts related to automating application management using winget through NinjaOne.

If you are running these scripts via NinjaOne automations, be aware that two separate automations are required due to how winget behaves under different execution contexts:

- **SYSTEM context automation**
  - Verifies that winget is installed and installs it if necessary.
  - Updates applications installed at the machine level.

- **User context automation**
  - Runs in the context of the logged-in user.
  - Updates applications installed on a per-user basis.

Note: Some packages require administrative privileges to install or update. In these cases, UAC prompts must be accepted, or administrator credentials must be provided for non-admin users.
