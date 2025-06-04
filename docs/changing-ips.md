# Changing VPS IPs in Fabric Zakat Network

This guide explains how to update the network configuration when moving to new VPS instances.

## Step 1: Update Configuration

Edit `scripts/config/orgs-config.sh` to update IP addresses:

```bash
# Organization IPs - Change these when moving to new VPSes
ORG_IPS=("10.104.0.2" "10.104.0.4")  # Update with new Org1 and Org2 IPs

# Orderer configuration
ORDERER_IP="10.104.0.3"  # Update with new orderer IP
```

## Step 2: Update Hosts Files

The `setup-hosts.sh` utility will automatically update `/etc/hosts` on all machines:

```bash
# Run from control machine
./scripts/helper/setup-hosts.sh
```

This will:
- Generate the correct hosts entries
- Update `/etc/hosts` on each machine via SSH
- Display entries to add to your control machine

## Step 3: Stop Network Components

1. Stop CAs:
```bash
./scripts/ca-servers-docker-stop.sh
```

2. Stop other components (if running):
```bash
# Stop orderer and peers as needed
./scripts/18-deploy-orderer.sh stop  # if implemented
./scripts/19-deploy-peers-clis.sh stop  # if implemented
```

## Step 4: Update SSH Configuration

1. Update your `~/.ssh/config` with new IPs:
```
Host orderer.fabriczakat.local
    HostName <new-orderer-ip>
    User fabricadmin
    IdentityFile ~/.ssh/fabric_key

Host org1.fabriczakat.local
    HostName <new-org1-ip>
    User fabricadmin
    IdentityFile ~/.ssh/fabric_key

Host org2.fabriczakat.local
    HostName <new-org2-ip>
    User fabricadmin
    IdentityFile ~/.ssh/fabric_key
```

2. Test SSH access to all machines:
```bash
ssh fabricadmin@<new-orderer-ip> "echo 'Connection successful'"
ssh fabricadmin@<new-org1-ip> "echo 'Connection successful'"
ssh fabricadmin@<new-org2-ip> "echo 'Connection successful'"
```

## Step 5: Start Network Components

1. Start CAs:
```bash
./scripts/ca-servers-docker-start.sh
```

2. Verify CA access:
```bash
# Test TLS CA
curl -k https://<new-orderer-ip>:7054/cainfo

# Test Org CAs
curl -k https://<new-org1-ip>:7054/cainfo
curl -k https://<new-org2-ip>:7054/cainfo
```

3. Start other components:
```bash
# Deploy orderer and peers
./scripts/18-deploy-orderer.sh start  # if implemented
./scripts/19-deploy-peers-clis.sh start  # if implemented
```

## Troubleshooting

1. **Certificate Issues**
   - If TLS certificates contain old IPs/hostnames, you may need to regenerate them
   - Use the CA enrollment scripts to generate new certificates

2. **Connection Issues**
   - Verify Docker network connectivity
   - Check firewall rules on new VPSes
   - Ensure ports 7054 (CA), 7050 (orderer), 7051 (peer) are accessible

3. **DNS Resolution**
   - Run `ping` and `nslookup` to verify hostname resolution
   - Check `/etc/hosts` entries on all machines

## Notes

- All scripts source IP addresses from `orgs-config.sh`
- The Docker Compose template uses environmental variables for configuration
- CA servers on different machines use the same port (7054) since they're on different hosts
- Make sure to update any external applications or services that connect to the network

## Future Improvements

Consider implementing:
- Automated IP validation
- Configuration backup/restore
- Network component health checks
- Certificate renewal procedures
