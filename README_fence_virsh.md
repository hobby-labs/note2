## Use fence_virsh (If you do not use fence_sbd)
Are those environment stands on KVM. We can use `fence_virsh` agent for STONITH.
STONITH is a feature that allows the cluster to forcibly power off a node that is not responding, to prevent data corruption. It is recommended to have STONITH configured in production environments.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
systemd-detect-virt
> kvm

yum install -y fence-agents-virsh

ls /usr/sbin/fence_virsh
> /usr/sbin/fence_virsh
```

Create SSH key for passwordless access.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519
# Then copy the public key and private key to hypervisor node.
```

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
chmod 600 /root/.ssh/id_ed25519
```



# Test cluster and failover

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
# Test VIP
ping -c 3 10.1.0.10

# Test MariaDB via VIP
mysql -h 10.1.0.10 -u root -p -e "SELECT @@hostname;"

# Test failover
crm_standby -v on -N drbd101
sleep 20
crm_mon -1

# Bring back
crm_standby -v off -N drbd101
sleep 20
crm_mon -1
```

// Snapshot init_cluster (Test failover and recovery)

# Fencing

TODO: This instruction should use the user that only be able to run virsh on hypervisor nodes not root.
TODO: This instruction should implement hybrid fencing with fence_virsh as primary and fence_sbd as secondary. If fence_virsh fails, then use fence_sbd to fence the node.

Create private keys for fencing.

* drbd101, drbd102, drbd103: MariaDB Cluster 1
```
ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519_fence
```

Copy the public keys to the hypervisor nodes and add to `authorized_keys` with command restriction to only allow `fence_virsh` commands

```
cat >> /root/.ssh/authorized_keys << 'EOF'
command="/usr/local/bin/fence_virsh_wrapper.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...key-from-drbd101...
command="/usr/local/bin/fence_virsh_wrapper.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...key-from-drbd102...
command="/usr/local/bin/fence_virsh_wrapper.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...key-from-drbd103...
EOF
```



# From any cluster node
ssh -i /root/.ssh/id_fence root@<hypervisor-ip> 'virsh list --all'        # ✅
ssh -i /root/.ssh/id_fence root@<hypervisor-ip> 'virsh domstate drbd101'  # ✅
ssh -i /root/.ssh/id_fence root@<hypervisor-ip> 'whoami'                  # ❌
ssh -i /root/.ssh/id_fence root@<hypervisor-ip>                           # ❌

# Test fence agent directly
fence_virsh -o list -a <hypervisor-ip> -l root -k /root/.ssh/id_fence -v
fence_virsh -o status -a <hypervisor-ip> -l root -k /root/.ssh/id_fence -n drbd101 -v


// Snapshot init_cluster_ssh_keygen

* fence_virsh_wrapper.sh (/usr/local/bin/fence_virsh_wrapper.sh on each hypervisor node)
```
#!/bin/bash
# filepath: /usr/local/bin/fence_virsh_wrapper.sh
# Restrict SSH commands to only virsh operations needed by fence_virsh

# List of allowed VM names
ALLOWED_VMS="drbd101 drbd102 drbd103"

# Get the original command sent via SSH
ORIGINAL_CMD="$SSH_ORIGINAL_COMMAND"

# Log for auditing
logger -t fence_virsh_wrapper "Command received from ${SSH_CLIENT%% *}: $ORIGINAL_CMD"

# If no command provided (interactive shell attempt), reject
if [ -z "$ORIGINAL_CMD" ]; then
    logger -t fence_virsh_wrapper "REJECTED: interactive shell attempt"
    echo "Error: Interactive shell not allowed"
    exit 1
fi

# Parse command
CMD_VIRSH=$(echo "$ORIGINAL_CMD" | awk '{print $1}')
CMD_ACTION=$(echo "$ORIGINAL_CMD" | awk '{print $2}')
CMD_ARG1=$(echo "$ORIGINAL_CMD" | awk '{print $3}')
CMD_ARG2=$(echo "$ORIGINAL_CMD" | awk '{print $4}')

# Must start with "virsh"
if [ "$CMD_VIRSH" != "virsh" ]; then
    logger -t fence_virsh_wrapper "REJECTED: not a virsh command: $ORIGINAL_CMD"
    echo "Error: Only virsh commands are allowed"
    exit 1
fi

# Check allowed actions
case "$CMD_ACTION" in
    list)
        # Allow: "virsh list" and "virsh list --all"
        if [ -z "$CMD_ARG1" ] || [ "$CMD_ARG1" = "--all" ]; then
            /usr/bin/virsh list $CMD_ARG1
        else
            logger -t fence_virsh_wrapper "REJECTED: invalid list argument: $CMD_ARG1"
            echo "Error: Invalid argument"
            exit 1
        fi
        ;;
    domstate|destroy|start|reboot)
        # Validate VM name is in allowed list
        ALLOWED=false
        for vm in $ALLOWED_VMS; do
            if [ "$CMD_ARG1" = "$vm" ]; then
                ALLOWED=true
                break
            fi
        done

        if [ "$ALLOWED" = true ]; then
            # No extra arguments allowed
            if [ -n "$CMD_ARG2" ]; then
                logger -t fence_virsh_wrapper "REJECTED: extra arguments: $ORIGINAL_CMD"
                echo "Error: Extra arguments not allowed"
                exit 1
            fi
            /usr/bin/virsh "$CMD_ACTION" "$CMD_ARG1"
        else
            logger -t fence_virsh_wrapper "REJECTED: VM '$CMD_ARG1' not in allowed list"
            echo "Error: VM not allowed"
            exit 1
        fi
        ;;
    *)
        logger -t fence_virsh_wrapper "REJECTED: action '$CMD_ACTION' not allowed"
        echo "Error: Action not allowed"
        exit 1
        ;;
esac
```

```
# On drbd101 only

cibadmin --create --scope resources --xml-text '
<primitive id="fence_virsh_drbd101" class="stonith" type="fence_virsh">
  <instance_attributes id="fence_virsh_drbd101-attrs">
    <nvpair id="fence_virsh_drbd101-ip" name="ip" value="<hypervisor-ip>"/>
    <nvpair id="fence_virsh_drbd101-ssh" name="ssh" value="true"/>
    <nvpair id="fence_virsh_drbd101-username" name="username" value="root"/>
    <nvpair id="fence_virsh_drbd101-plug" name="plug" value="drbd101"/>
    <nvpair id="fence_virsh_drbd101-identity_file" name="identity_file" value="/root/.ssh/id_fence"/>
    <nvpair id="fence_virsh_drbd101-pcmk_host_list" name="pcmk_host_list" value="drbd101"/>
  </instance_attributes>
  <operations>
    <op id="fence_virsh_drbd101-monitor" name="monitor" interval="60s"/>
  </operations>
</primitive>'

cibadmin --create --scope resources --xml-text '
<primitive id="fence_virsh_drbd102" class="stonith" type="fence_virsh">
  <instance_attributes id="fence_virsh_drbd102-attrs">
    <nvpair id="fence_virsh_drbd102-ip" name="ip" value="<hypervisor-ip>"/>
    <nvpair id="fence_virsh_drbd102-ssh" name="ssh" value="true"/>
    <nvpair id="fence_virsh_drbd102-username" name="username" value="root"/>
    <nvpair id="fence_virsh_drbd102-plug" name="plug" value="drbd102"/>
    <nvpair id="fence_virsh_drbd102-identity_file" name="identity_file" value="/root/.ssh/id_fence"/>
    <nvpair id="fence_virsh_drbd102-pcmk_host_list" name="pcmk_host_list" value="drbd102"/>
  </instance_attributes>
  <operations>
    <op id="fence_virsh_drbd102-monitor" name="monitor" interval="60s"/>
  </operations>
</primitive>'

cibadmin --create --scope resources --xml-text '
<primitive id="fence_virsh_drbd103" class="stonith" type="fence_virsh">
  <instance_attributes id="fence_virsh_drbd103-attrs">
    <nvpair id="fence_virsh_drbd103-ip" name="ip" value="<hypervisor-ip>"/>
    <nvpair id="fence_virsh_drbd103-ssh" name="ssh" value="true"/>
    <nvpair id="fence_virsh_drbd103-username" name="username" value="root"/>
    <nvpair id="fence_virsh_drbd103-plug" name="plug" value="drbd103"/>
    <nvpair id="fence_virsh_drbd103-identity_file" name="identity_file" value="/root/.ssh/id_fence"/>
    <nvpair id="fence_virsh_drbd103-pcmk_host_list" name="pcmk_host_list" value="drbd103"/>
  </instance_attributes>
  <operations>
    <op id="fence_virsh_drbd103-monitor" name="monitor" interval="60s"/>
  </operations>
</primitive>'
```

// TODO: Step 7: Add Location Constraints


* authorized

# Move resource group to trigger failover

```
# Move resource group to a specific node
crm_resource --move --resource grp_mariadb --node drbd102
crm_mon -Af1
> Cluster Summary:
>   * Stack: corosync
>   * Current DC: drbd102 (version 2.0.5-ba59be71228) - partition with quorum
>   * Last updated: Sun Mar  1 02:31:49 2026
>   * Last change:  Sun Mar  1 02:31:41 2026 by root via crm_resource on drbd101
>   * 3 nodes configured
>   * 6 resource instances configured
> 
> Node List:
>   * Online: [ drbd101 drbd102 drbd103 ]
> 
> Active Resources:
>   * Clone Set: ms_drbd_mariadb [drbd_mariadb] (promotable):
>     * Masters: [ drbd102 ]
>     * Slaves: [ drbd101 drbd103 ]
>   * Resource Group: grp_mariadb:
>     * fs_mariadb	(ocf::heartbeat:Filesystem):	 Started drbd102
>     * svc_mariadb	(systemd:mariadb):	 Started drbd102
>     * vip_mariadb	(ocf::heartbeat:IPaddr2):	 Started drbd102
> 
> Node Attributes:
>   * Node: drbd101:
>     * master-drbd_mariadb             	: 10000
>   * Node: drbd102:
>     * master-drbd_mariadb             	: 10000
>   * Node: drbd103:
>     * master-drbd_mariadb             	: 10000
> 
> Migration Summary:

# Check constraints to verify resource is running on the same node as primary DRBD
cibadmin --query --scope constraints
> <constraints>
>   <rsc_colocation id="col_grp_drbd" rsc="grp_mariadb" score="INFINITY" with-rsc="ms_drbd_mariadb" with-rsc-role="Master"/>
>   <rsc_order first="ms_drbd_mariadb" id="ord_drbd_grp" then="grp_mariadb" then-action="start"/>
>   <rsc_location id="cli-prefer-grp_mariadb" rsc="grp_mariadb" role="Started" node="drbd102" score="INFINITY"/>
> </constraints>

# IMPORTANT: Clear the migration constraint after verifying
crm_resource --clear --resource grp_mariadb
> Removing constraint: cli-prefer-grp_mariadb

# Check constraints again to verify migration constraint is removed
cibadmin --query --scope constraints
> <constraints>
>   <rsc_colocation id="col_grp_drbd" rsc="grp_mariadb" score="INFINITY" with-rsc="ms_drbd_mariadb" with-rsc-role="Master"/>
>   <rsc_order first="ms_drbd_mariadb" id="ord_drbd_grp" then="grp_mariadb" then-action="start"/>
>-  <rsc_location id="cli-prefer-grp_mariadb" rsc="grp_mariadb" role="Started" node="drbd102" score="INFINITY"/>
> </constraints>
```

Put node in standby to trigger failover.

```
crm_standby -v on -N drbd102

crm_standby -G -N drbd102
> scope=nodes  name=standby value=on

crm_mon -Af1
> Cluster Summary:
>   * Stack: corosync
>   * Current DC: drbd102 (version 2.0.5-ba59be71228) - partition with quorum
>   * Last updated: Sun Mar  1 02:40:29 2026
>   * Last change:  Sun Mar  1 02:40:16 2026 by root via crm_attribute on drbd101
>   * 3 nodes configured
>   * 6 resource instances configured
> 
> Node List:
>   * Node drbd102: standby
>   * Online: [ drbd101 drbd103 ]
> 
> Active Resources:
>   * Clone Set: ms_drbd_mariadb [drbd_mariadb] (promotable):
>     * Masters: [ drbd101 ]
>     * Slaves: [ drbd103 ]
>   * Resource Group: grp_mariadb:
>     * fs_mariadb	(ocf::heartbeat:Filesystem):	 Started drbd101
>     * svc_mariadb	(systemd:mariadb):	 Started drbd101
>     * vip_mariadb	(ocf::heartbeat:IPaddr2):	 Started drbd101
> 
> Node Attributes:
>   * Node: drbd101:
>     * master-drbd_mariadb             	: 10000
>   * Node: drbd103:
>     * master-drbd_mariadb             	: 10000
> 
> Migration Summary:

crm_standby -v off -N drbd102
crm_standby -G -N drbd102
> scope=nodes  name=standby value=off

crm_mon -Af1
> Cluster Summary:
>   * Stack: corosync
>   * Current DC: drbd102 (version 2.0.5-ba59be71228) - partition with quorum
>   * Last updated: Sun Mar  1 02:47:27 2026
>   * Last change:  Sun Mar  1 02:47:15 2026 by root via crm_attribute on drbd101
>   * 3 nodes configured
>   * 6 resource instances configured
> 
> Node List:
>   * Online: [ drbd101 drbd102 drbd103 ]
> 
> Active Resources:
>   * Clone Set: ms_drbd_mariadb [drbd_mariadb] (promotable):
>     * Masters: [ drbd101 ]
>     * Slaves: [ drbd102 drbd103 ]
>   * Resource Group: grp_mariadb:
>     * fs_mariadb	(ocf::heartbeat:Filesystem):	 Started drbd101
>     * svc_mariadb	(systemd:mariadb):	 Started drbd101
>     * vip_mariadb	(ocf::heartbeat:IPaddr2):	 Started drbd101
> 
> Node Attributes:
>   * Node: drbd101:
>     * master-drbd_mariadb             	: 10000
>   * Node: drbd102:
>     * master-drbd_mariadb             	: 10000
>   * Node: drbd103:
>     * master-drbd_mariadb             	: 10000
> 
> Migration Summary:
```

* On primary node, failover by killing corosync process to simulate crash.
```
killall -9 corosync
```