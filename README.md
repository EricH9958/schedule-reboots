# schedule-reboots

Staged reboot and maintenance scripts for two Ubuntu 24.04 servers, with optional Plex session termination through Tautulli.

This repository contains public, anonymized example scripts based on a real maintenance workflow where one primary server schedules and coordinates maintenance tasks for itself and a second server.

## What this does

The main scheduler script can:

- Queue a reboot for Server-1 with `at`
- Queue a pre-reboot Plex stream termination step through Tautulli
- Queue a Plex container stop on Server-2
- Queue a reboot for Server-2 after a configurable delay
- Cancel all queued maintenance jobs on both servers

The Tautulli helper script can:

- Kill all active Plex sessions with a custom message
- Kill only a specific user's active Plex sessions with a custom message

## Repository layout

```text
schedule-reboots/
├── README.md
├── LICENSE
├── .gitignore
├── docs/
└── scripts/
    ├── schedule-reboots.sh
    └── tautulli-kill-streams.sh
```

## Scripts

### `scripts/schedule-reboots.sh`

Interactive staged reboot scheduler for two Ubuntu 24.04 servers.

Features:

- Prompts for reboot date and time
- Supports defaults for tomorrow, 1:00 AM, and a reboot gap
- Schedules Server-1 first
- Schedules stream termination before reboot
- Schedules Plex container stop before reboot
- Sends the Server-2 reboot from Server-1 over SSH
- Can cancel all queued `at` jobs on both systems

### `scripts/tautulli-kill-streams.sh`

Tautulli helper script for terminating active Plex sessions.

Modes:

- `--all` kills every active stream
- `--user username` kills only matching active streams
- `--message "text"` changes the message shown when the session is terminated

## Requirements

These scripts are written for **Ubuntu 24.04**.

### Server requirements

- Two Ubuntu 24.04 servers
- `at` installed and enabled
- Docker installed if you are using the Plex stop step
- Key-based SSH from Server-1 to Server-2
- A sudo rule on Server-2 that allows the remote user to run reboot non-interactively
- Tautulli with API access if you are using the Plex stream termination step

### Required commands

The scheduler expects these commands to exist:

- `at`
- `atq`
- `atrm`
- `date`
- `ssh`
- `systemctl`
- `hostname`
- `logger`
- `docker`

The Tautulli helper expects:

- `curl`
- `jq`

## Install dependencies

On Ubuntu 24.04, install the required packages:

```bash
sudo apt update
sudo apt install -y at openssh-client curl jq
```

### Additional prerequisites  

- Docker must already be installed on the server that manages Plex.
- The `atd` service must be enabled and running:
  ```bash
  sudo systemctl enable --now atd
  ```
- Key-based SSH from Server-1 to Server-2 must already be configured.
- A sudo rule on Server-2 must allow the remote user to run:
  ```bash
  sudo -n /usr/bin/systemctl reboot
  ```
- Tautulli must be reachable and API access must be enabled.

## Before use

These scripts are **examples** and must be edited for your own environment.

### Update the scheduler script

Edit these variables in `scripts/schedule-reboots.sh`:

- `S2_HOST`
- `S2_PORT`
- `S2_USER`
- `S2_KEY`
- `S2_KILL_SCRIPT`
- `S2_PLEX_CONTAINER`

Also review:

- The default reboot gap
- The maintenance message
- The hostname check
- Any local script paths

### Update the Tautulli script

Edit these variables in `scripts/tautulli-kill-streams.sh`:

- `TAUTULLI_URL`
- `TAUTULLI_API_KEY`

## Important behavior

### Plex restart policy

If your maintenance flow stops Plex before reboot, your Docker restart policy matters.

For example:

- `restart: unless-stopped` means Plex will stay down after reboot if you stopped it manually before the reboot
- `restart: always` means Plex will be brought back automatically after reboot even if it was stopped beforehand

### Tautulli message behavior

The stream termination helper works by calling Tautulli's session termination API.

That means:

- it can show a message when ending a stream
- it does **not** provide a warning-only in-player popup
- warning-only notifications would need a separate notification flow

## Installation

Clone the repository:

```bash
git clone https://github.com/EricH9958/schedule-reboots.git
cd schedule-reboots
```

Make the public scripts executable:

```bash
chmod 755 scripts/schedule-reboots.sh scripts/tautulli-kill-streams.sh
```
Before running the scripts, edit the placeholder values described in the **Before use** section.

## Usage

### Run the staged reboot scheduler

Run as root on Server-1:

```bash
sudo ./scripts/schedule-reboots.sh
```

The script will prompt you to:

- schedule reboot jobs, or
- cancel all queued jobs

### Kill all active Plex streams

```bash
sudo ./scripts/tautulli-kill-streams.sh --all --message "Scheduled maintenance in progress. Playback has been stopped."
```

### Kill streams for one user only

```bash
sudo ./scripts/tautulli-kill-streams.sh --user someuser --message "Scheduled maintenance in progress. Playback has been stopped."
```

## Suggested test workflow

Before trusting the scheduler in production:

1. Confirm SSH from Server-1 to Server-2 works with the configured key.
2. Confirm the remote user on Server-2 can run:
   ```bash
   sudo -n /usr/bin/systemctl reboot
   ```
3. Confirm Tautulli can see active Plex sessions.
4. Test the Tautulli helper script manually against a test stream.
5. Test the scheduler with a short maintenance window.

## Safety notes

These scripts can:

- terminate active Plex sessions
- stop Docker containers
- reboot systems
- cancel queued `at` jobs

Review them carefully before use in any environment.

## Public vs private files

This repository is intended to contain the **anonymized public versions** of the scripts.

Do not commit::

- real internal IP addresses
- real SSH key paths
- API keys
- production-only backup scripts
- environment-specific private files

## License

This repository includes a license file at the repository root. GitHub recommends adding a license so others know how they may use, modify, and distribute the code.
