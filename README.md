# ml-dev-docker

A GPU-enabled Docker dev environment based on `nvidia/cuda:12.6.3-cudnn-devel-ubuntu22.04`.

## Launch

```bash
bash run_docker.sh
```

`run_docker.sh` handles everything in order:
1. [Optional] Installs Docker
2. Starts `ssh-agent` and loads your private key (via `start_ssh_agent.sh`)
3. Builds the Docker image
4. Launches the container

## Running as Root (Safe in Rootless Docker)

The container runs as root, which is safe here because Docker itself runs in **rootless mode** — the Docker daemon is launched as the host user, not as system root. This means:

- Container root maps to the host user's UID, not actual system root
- The container has no elevated privileges beyond what the host user already has
- Files created inside the container appear as owned by the host user, so the host can freely delete them
- No `sudo` is needed inside the container — you are already root

## SSH Agent Forwarding

The container uses SSH agent forwarding so that git operations (`git push`, `git pull`, `ssh`) work inside the container without copying private keys into it.

### Why SSH agent forwarding over personal access tokens (PAT)

| | SSH Agent Forwarding | Personal Access Token |
|---|---|---|
| Secret exposure | Private key never enters the container | Token must be stored inside the container or typed each time |
| Expiry | No expiry unless key is revoked | Tokens expire and must be rotated |
| Scope | Key-level access, tied to your identity | Token scope can be misconfigured (too broad) |
| Revocation | Revoke one key, affects all containers at once | Each token must be revoked individually |
| Convenience | One-time setup, works automatically | Must re-enter or re-inject token on each new container |

### How it works

`run_docker.sh` automatically sources `start_ssh_agent.sh`, which checks if `ssh-agent` is running and starts it if needed. The agent socket is then mounted into the container at `/ssh-agent` — the private key never enters the container.

### After host reboot

`ssh-agent` does not survive a reboot. Simply re-run `run_docker.sh` — it will start a fresh agent, load your key, and relaunch the container with the new socket mounted:

```bash
bash run_docker.sh
```
