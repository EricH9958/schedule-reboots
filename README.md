# schedule-reboots

Bash script for Ubuntu 24.04 that schedules staged reboots for two servers using `at`. The script is run on the primary server and uses SSH key-based access to queue a later reboot on the secondary server.

## Features

- Schedule reboot jobs for two servers in one run.
- Cancel all queued `at` jobs on both servers from the same script.
- Prompt-based interface with default answers for date, hour, minute, and AM/PM selection.
- 12-hour time entry with numeric AM/PM menu selection.
- Confirmation output in `MM/DD/YYYY HH:MM AM/PM` format before jobs are queued.

## Requirements

- Ubuntu 24.04 on both servers.
- `at` installed on both servers and `atd` enabled and running.
- SSH key-based access from the primary server to the secondary server.
- Root access on the primary server to run the script and queue the local reboot job.

## Installation

Copy the script to a root-owned admin path such as:

```bash
/usr/local/sbin/schedule-reboots.sh
chmod 700 /usr/local/sbin/schedule-reboots.sh
```

Install and enable `atd` on both servers:

```bash
apt update
apt install -y at
systemctl enable --now atd
```

## Configuration

Edit these variables in the script for the target environment:

- `S2_HOST`
- `S2_PORT`
- `S2_USER`
- `S2_KEY`
- `DEFAULT_GAP_MINUTES`

For a public GitHub repo, replace real usernames, hostnames, IP addresses, and key paths with generic placeholders before publishing.

## Usage

Run the script on the primary server as root:

```bash
/usr/local/sbin/schedule-reboots.sh
```

At startup, choose one of these activities:

- `1` to schedule reboot jobs.
- `2` to cancel all queued `at` jobs on both servers.

### Schedule mode

The script prompts for:

- Default date or a custom date.
- Default hour or a custom hour.
- Default minute or a custom minute.
- Default AM/PM or a numeric menu choice, `1` for AM and `2` for PM.
- Minutes between the primary and secondary reboot times.

It then shows a summary like:

- `06/29/2026 01:00 PM`
- `06/29/2026 01:15 PM`

before asking for final confirmation.

### Cancel mode

Cancel mode displays queued `at` jobs on both servers, asks for confirmation, and removes all queued jobs from both systems. This design assumes the script is the only workflow using `at` on those servers.

## Notes

- `at` may print `warning: commands will be executed using /bin/sh`; this is normal behavior, not an error.
- The script depends on successful SSH access from the primary server to the secondary server using the configured key path.
- The reboot order is primary server first, then secondary server after the configured gap.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
