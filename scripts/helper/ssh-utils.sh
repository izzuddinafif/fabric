#!/bin/bash

# Source the organization config
source "$(dirname "$0")/../config/orgs-config.sh"

# Execute command via SSH with error handling
# Arguments:
#   $1: IP address
#   $2: Command to execute
#   $3: Error message (optional)
ssh_exec() {
    local ip=$1
    local cmd=$2
    local error_msg=${3:-"Command failed"}
    
    ssh "fabricadmin@$ip" "$cmd"
    if [ $? -ne 0 ]; then
        echo "⛔ $error_msg on $ip"
        return 1
    fi
    return 0
}

# Copy file/directory via SCP with error handling
# Arguments:
#   $1: Source path
#   $2: IP address
#   $3: Destination path
#   $4: Error message (optional)
scp_file() {
    local src=$1
    local ip=$2
    local dest=$3
    local error_msg=${4:-"Failed to copy file"}
    
    # Check if source exists
    if [ ! -e "$src" ]; then
        echo "⛔ Source does not exist: $src"
        return 1
    fi
    
    # Create destination directory if needed
    local dest_dir=$(dirname "$dest")
    ssh_exec "$ip" "mkdir -p $dest_dir" "Failed to create destination directory"
    if [ $? -ne 0 ]; then return 1; fi
    
    # Copy the file/directory
    if [ -d "$src" ]; then
        scp -r "$src" "fabricadmin@$ip:$dest"
    else
        scp "$src" "fabricadmin@$ip:$dest"
    fi
    
    if [ $? -ne 0 ]; then
        echo "⛔ $error_msg to $ip"
        return 1
    fi
    return 0
}

# Verify remote file exists
# Arguments:
#   $1: IP address
#   $2: Remote file path
verify_remote_file() {
    local ip=$1
    local path=$2
    
    ssh "fabricadmin@$ip" "[ -f $path ]"
    if [ $? -ne 0 ]; then
        echo "⛔ Remote file not found: $path on $ip"
        return 1
    fi
    return 0
}

# Verify remote directory exists
# Arguments:
#   $1: IP address
#   $2: Remote directory path
verify_remote_dir() {
    local ip=$1
    local path=$2
    
    ssh "fabricadmin@$ip" "[ -d $path ]"
    if [ $? -ne 0 ]; then
        echo "⛔ Remote directory not found: $path on $ip"
        return 1
    fi
    return 0
}

# Execute multi-line script via SSH
# Arguments:
#   $1: IP address
#   $2: Multi-line script
#   $3: Error message (optional)
ssh_exec_script() {
    local ip=$1
    local script=$2
    local error_msg=${3:-"Script execution failed"}
    
    ssh "fabricadmin@$ip" "$script"
    if [ $? -ne 0 ]; then
        echo "⛔ $error_msg on $ip"
        return 1
    fi
    return 0
}

# Check remote command availability
# Arguments:
#   $1: IP address
#   $2: Command name
check_remote_command() {
    local ip=$1
    local cmd=$2
    
    ssh "fabricadmin@$ip" "command -v $cmd"
    return $?
}

# Install remote package if not present
# Arguments:
#   $1: IP address
#   $2: Command to check
#   $3: Install command
install_remote_package() {
    local ip=$1
    local check_cmd=$2
    local install_cmd=$3
    
    if ! check_remote_command "$ip" "$check_cmd"; then
        echo "  🔧 $check_cmd not found. Installing..."
        ssh_exec "$ip" "$install_cmd" "Failed to install $check_cmd"
        return $?
    fi
    echo "  ✅ $check_cmd is already installed."
    return 0
}

# Register an identity with the CA
# Arguments:
#   $1: IP address
#   $2: Identity name
#   $3: Identity secret
#   $4: Identity type
#   $5: CA URL
#   $6: MSP directory
#   $7: TLS cert path
register_identity() {
    local ip=$1
    local id_name=$2
    local id_secret=$3
    local id_type=$4
    local ca_url=$5
    local msp_dir=$6
    local tls_cert=$7

    local cmd="~/bin/fabric-ca-client register -d \
        --id.name $id_name \
        --id.secret $id_secret \
        --id.type $id_type \
        --mspdir $msp_dir \
        --tls.certfiles $tls_cert \
        -u $ca_url"

    ssh_exec "$ip" "$cmd" "Failed to register $id_name" || return 1
    return 0
}

# Enroll an identity with the CA
# Arguments:
#   $1: IP address
#   $2: Identity name
#   $3: Identity secret
#   $4: CA URL
#   $5: MSP directory
#   $6: TLS cert path
#   $7: Additional options (optional)
enroll_identity() {
    local ip=$1
    local id_name=$2
    local id_secret=$3
    local ca_url=$4
    local msp_dir=$5
    local tls_cert=$6
    local extra_opts=${7:-""}

    local cmd="~/bin/fabric-ca-client enroll -d \
        -u https://$id_name:$id_secret@$ca_url \
        --tls.certfiles $tls_cert \
        --mspdir $msp_dir \
        $extra_opts"

    ssh_exec "$ip" "$cmd" "Failed to enroll $id_name" || return 1
    return 0
}

# Create an MSP config.yaml file
# Arguments:
#   $1: IP address
#   $2: MSP directory
#   $3: CA cert filename
create_msp_config() {
    local ip=$1
    local msp_dir=$2
    local ca_cert=$3

    local config_yaml="NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/$ca_cert
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/$ca_cert
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/$ca_cert
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/$ca_cert
    OrganizationalUnitIdentifier: orderer"

    ssh_exec "$ip" "echo '$config_yaml' > $msp_dir/config.yaml" "Failed to create MSP config.yaml" || return 1
    return 0
}

# Copy and rename MSP files
# Arguments:
#   $1: IP address
#   $2: Source directory
#   $3: Destination directory
#   $4: File type (e.g., 'key', 'cert', 'cacert')
copy_msp_files() {
    local ip=$1
    local src_dir=$2
    local dest_dir=$3
    local file_type=$4

    local cmd=""
    case $file_type in
        "key")
            cmd="KEY_FILE=\$(find $src_dir/keystore -type f -name '*_sk' | head -n 1) && \
                 mv \"\$KEY_FILE\" $dest_dir/keystore/key.pem"
            ;;
        "cert")
            cmd="cp $src_dir/signcerts/* $dest_dir/signcerts/"
            ;;
        "cacert")
            cmd="cp $src_dir/cacerts/* $dest_dir/cacerts/"
            ;;
        *)
            echo "⛔ Unknown file type: $file_type"
            return 1
            ;;
    esac

    ssh_exec "$ip" "$cmd" "Failed to copy $file_type files" || return 1
    return 0
}

# Stop all CA servers on remote machine
# Arguments:
#   $1: IP address
stop_ca_servers() {
    local ip=$1
    local script="""
set +e # Allow commands to fail without exiting
echo \"  🛑 Stopping CA servers...\"

# Stop using PID files
for PID_FILE in \$(find ~/fabric -name \"fabric-ca-server-*.pid\" 2>/dev/null); do
    if [ -f \"\$PID_FILE\" ]; then
        PID=\$(cat \"\$PID_FILE\")
        if ps -p \$PID > /dev/null; then
            kill \$PID
            sleep 1
            if ps -p \$PID > /dev/null; then
                kill -9 \$PID
                sleep 1
            fi
        fi
        rm -f \"\$PID_FILE\"
    fi
done

# Force kill any remaining processes
pkill -9 -f fabric-ca-server 2>/dev/null

# Verify all are stopped
if pgrep -l -f fabric-ca-server; then
    echo \"    ⛔ Some CA server processes still running!\"
    return 1
else
    echo \"    ✅ All CA servers stopped.\"
    return 0
fi
"""
    ssh_exec_script "$ip" "$script" "Failed to stop CA servers"
    return $?
}

# Clean up Fabric artifacts on remote machine
# Arguments:
#   $1: IP address
clean_fabric_artifacts() {
    local ip=$1
    local script="""
set +e # Allow commands to fail for cleanup

# Stop CA servers first
$(stop_ca_servers "$ip")

# Remove fabric directory
echo \"  🗑️ Removing fabric directory...\"
rm -rf ~/fabric/

# Verify removal
if [ -d ~/fabric ]; then
    echo \"    ⛔ fabric directory still exists!\"
    return 1
else
    echo \"    ✅ fabric directory removed.\"
    return 0
fi
"""
    ssh_exec_script "$ip" "$script" "Failed to clean up Fabric artifacts"
    return $?
}
