#!/bin/sh

# See https://github.com/phytec/meta-connagtive/blob/zeus/recipes-support/provisioning/files/provision-tpm.sh for inspiration

# Cleanup
function finish {
	ssscli disconnect
	echo "Done"
}
trap finish EXIT

# User Input
echo "This script will reset the SE050. Do you want to continue (y/n)?"

read answer

if [ "$answer" != "${answer#[Nn]}" ] ;then
    exit
else
    echo "Continuing ..."
fi

# Checking if provisioning webhook is running
health_status=$(curl --location --request POST 'https://raspberrypi:9000/hooks/health_status' --header 'Content-Type: application/json')

if [ "$health_status" != "Good" ] ;then
    echo "Provisioning webhook is not running as expected. Aborting ..."
	exit
else
    echo "Provisioning webhook is running as expected. Continuing ..."
fi

DeviceName=$1

if echo $DeviceName | grep -E -q "^[a-zA-Z_]([a-zA-Z0-9_-]{0,31}|[a-zA-Z0-9_-]{0,30}\$)$"; then 
	echo "The given device name is valid"
else 
	echo "The given device name does not match the following regex: ^[a-zA-Z_]([a-zA-Z0-9_-]{0,31}|[a-zA-Z0-9_-]{0,30}\$)$"
	exit
fi

AWSCLIENT_HOME=/data/config/os/aws/
CUSTOMER_NAME=automation-one

# Create Folder Structure
echo "Creating Folder Structure ..."
mkdir -p /data/config/os/aws/certs /data/config/os/aws/config
# mkdir -p $(jq -r '.rauc_hawkbit_client_config_dir' config/config.json)
mkdir -p /data/config/os/hawkbit/
# mkdir -p "$(jq -r '.remote_manager_config_dir' config/config.json)/.ssh"
mkdir -p /config/os/root/.ssh/
# mkdir -p $(jq -r '.maintenance_task_temp_download_dir' config/config.json)
mkdir -p /data/config/os/dm/downloads/

cd $AWSCLIENT_HOME

echo "Writing template for awsclient config ..."
cat > config/config.json <<EOF
{
  "endpoint": "aqbh9vo6udjdm-ats.iot.eu-central-1.amazonaws.com",
  "mqtt_port": 8883,
  "https_port": 443,
  "greengrass_discovery_port": 8443,
  "root_ca_relative_path": "certs/rootCA.crt",
  "device_certificate_relative_path": "certs/cert.pem",
  "device_private_key_relative_path": "certs/privkey.pem",
  "tls_handshake_timeout_msecs": 60000,
  "tls_read_timeout_msecs": 2000,
  "tls_write_timeout_msecs": 2000,
  "aws_region": "eu-central-1",
  "aws_access_key_id": "",
  "aws_secret_access_key": "",
  "aws_session_token": "",
  "client_id": "CLIENT_ID",
  "thing_name": "THING_NAME",
  "is_clean_session": true,
  "mqtt_command_timeout_msecs": 20000,
  "keepalive_interval_secs": 600,
  "minimum_reconnect_interval_secs": 1,
  "maximum_reconnect_interval_secs": 128,
  "maximum_acks_to_wait_for": 32,
  "action_processing_rate_hz": 5,
  "maximum_outgoing_action_queue_length": 32,
  "discover_action_timeout_msecs": 300000,
  "shadow_update_interval_secs": 0,
  "rauc_hawkbit_client_config_dir": "/data/config/os/hawkbit/",
  "rauc_hawkbit_client_config_file": "config.cfg",
  "remote_manager_config_dir": "/data/config/os/esec/",
  "remote_manager_config_file": "RemoteManager.conf",
  "ssh_pub_key_dir": "/config/os/root/.ssh/",
  "ssh_pub_key_file": "id_ecdsa.pub",
  "isoconnect_app_config_dir": "/data/config/app_isoconnect/config/",
  "isoconnect_app_config_file": "customer_config.txt",
  "isoconnect_app_config_signature_file": "customer_config.txt.sig",
  "maintenance_task_temp_download_dir": "/data/config/os/dm/downloads/",
  "maintenance_task_download_whitelist_path": "/data/config/os/aws/config/download_whitelist.txt",
  "maintenance_task_command_whitelist_path": "/data/config/os/aws/config/command_whitelist.txt",
  "log_database_path": "/data/config/os/dm/awsclient_log_database.db",
  "desired_hawkbit_server_url": "",  
  "shadow_commands": [
     ["timer", "grep OnUnitActiveSec= /etc/systemd/system/awsclient.timer | grep -o [^=]*.$ | tr -d \"\\n\""],
     ["fs_data", "df | grep /data$ | tr -s \" \" | tr -d \"\\n\""],
     ["fs_log", "df | grep /var/volatile$ | tr -s \" \" | tr -d \"\\n\""],
     ["fs_root", "df | grep /$ | tr -s \" \" | tr -d \"\\n\""],
     ["up", "cat /proc/uptime | tr -d \"\\n\""],
     ["krn", "cat /proc/version | tr -d \"\\n\""],
     ["cpu", "cat /proc/loadavg | tr -d \"\\n\""],
     ["mem_a", "grep MemAvailable /proc/meminfo | tr -s \" \" | cut -d \" \" -f2 | tr -d \"\\n\""],
     ["mem_f", "grep MemFree /proc/meminfo | tr -s \" \" | cut -d \" \" -f2 | tr -d \"\\n\""],
     ["mem_t", "grep MemTotal /proc/meminfo | tr -s \" \" | cut -d \" \" -f2 | tr -d \"\\n\""],
     ["remote_manager_version", "remotemanager -v | tr -d \"\\n\""],
     ["remotemanager_service_status", "systemctl is-active remotemanager.service | tr -d \"\\n\""],
     ["rauc-hawkbit-updater", " rauc-hawkbit-updater -v | tr -d \"\\n\""],
     ["hwver", "echo -n 99"],
     ["devtype", "echo -n 99"],
     ["serial", "echo -n 99"]   
  ]
}
EOF

echo "Writing AWS Root Certificate ..."
cat > certs/rootCA.crt <<EOF
-----BEGIN CERTIFICATE-----
MIIDQTCCAimgAwIBAgITBmyfz5m/jAo54vB4ikPmljZbyjANBgkqhkiG9w0BAQsF
ADA5MQswCQYDVQQGEwJVUzEPMA0GA1UEChMGQW1hem9uMRkwFwYDVQQDExBBbWF6
b24gUm9vdCBDQSAxMB4XDTE1MDUyNjAwMDAwMFoXDTM4MDExNzAwMDAwMFowOTEL
MAkGA1UEBhMCVVMxDzANBgNVBAoTBkFtYXpvbjEZMBcGA1UEAxMQQW1hem9uIFJv
b3QgQ0EgMTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALJ4gHHKeNXj
ca9HgFB0fW7Y14h29Jlo91ghYPl0hAEvrAIthtOgQ3pOsqTQNroBvo3bSMgHFzZM
9O6II8c+6zf1tRn4SWiw3te5djgdYZ6k/oI2peVKVuRF4fn9tBb6dNqcmzU5L/qw
IFAGbHrQgLKm+a/sRxmPUDgH3KKHOVj4utWp+UhnMJbulHheb4mjUcAwhmahRWa6
VOujw5H5SNz/0egwLX0tdHA114gk957EWW67c4cX8jJGKLhD+rcdqsq08p8kDi1L
93FcXmn/6pUCyziKrlA4b9v7LWIbxcceVOF34GfID5yHI9Y/QCB/IIDEgEw+OyQm
jgSubJrIqg0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC
AYYwHQYDVR0OBBYEFIQYzIU07LwMlJQuCFmcx7IQTgoIMA0GCSqGSIb3DQEBCwUA
A4IBAQCY8jdaQZChGsV2USggNiMOruYou6r4lK5IpDB/G/wkjUu0yKGX9rbxenDI
U5PMCCjjmCXPI6T53iHTfIUJrU6adTrCC2qJeHZERxhlbI1Bjjt/msv0tadQ1wUs
N+gDS63pYaACbvXy8MWy7Vu33PqUXHeeE6V/Uq2V8viTO96LXFvKWlJbYK8U90vv
o/ufQJVtMVT8QtPHRh8jrdkPSHCa2XV4cdFyQzR1bldZwgJcJmApzyMZFo6IQ6XU
5MsI+yMRQ+hDKXJioaldXgjUkK642M4UwtBV8ob2xJNDd2ZhwLnoQdeXeGADbkpy
rqXRfboQnoZsG4q5WTP468SQvvG5
-----END CERTIFICATE-----
EOF

ssscli disconnect

# SE050 Operations
echo "Connecting to SE050 via i2c ..."
ssscli connect se05x t1oi2c /dev/i2c-0:0x48

# Resetting the SE050
echo "Resetting the SE050 ..."
ssscli se05x reset

# Getting the UID of the SE050
echo "Getting the UID of the SE050 ..."
uid=0x$(ssscli se05x uid 2> /dev/null | grep "Unique ID: " | grep -o -E "[0-9a-f]{36}")
echo "uid=${uid}"

# Modifying the config.json file of the awsclient according to the uid of the SE050
echo "Modifying the config file of the awsclient ..."
jq --arg uid "$uid" '.thing_name = $uid | .client_id = $uid' config/config.json  > /tmp/config.json && mv /tmp/config.json config/config.json

echo "Generating a NIST_P256 private key ..."
ssscli generate ecc 0x20181006 NIST_P256

echo "Removing existing privkey.pem file ..."
rm certs/privkey.pem

echo "Generating refpem for NIST_P256 private key ..."
ssscli refpem ecc pair 0x20181006 certs/privkey.pem

# Creating the CSR
echo "Exporting environment variables ..."
export OPENSSL_CONF=/etc/ssl/openssl_sss_se050.cnf
export EX_SSS_BOOT_SSS_PORT=/dev/i2c-0:0x48

echo "Removing existing certificate file ..."
rm "certs/$uid.pem"

echo "Creating the CSR ..."
openssl req -subj "/CN=$uid/pseudonym=$DeviceName" -batch -new -key certs/privkey.pem -out "certs/$uid.pem"

echo "Unsetting the environment variables ..."
unset OPENSSL_CONF
unset EX_SSS_BOOT_SSS_PORT

echo "Converting the CSR to base64 ..."
csr_base64=$(openssl base64 -in "certs/$uid.pem")
csr_base64_trimmed=$(echo ${csr_base64} | tr -d '\n')
csr_base64_trimmed=$(echo ${csr_base64_trimmed} | tr -d ' ')

echo "Requesting certificate from raspberry pi ..."
curl --location --request POST 'https://raspberrypi:9000/hooks/issue_cert' --header 'Content-Type: application/json' --data-raw "{\"binary\":\"${csr_base64_trimmed}\"}" > certs/cert.pem

echo "Writing certificates to SE050 ..."
ssscli set cert 0x20181002 --format PEM certs/rootCA.crt
ssscli set cert 0x20181004 --format PEM certs/cert.pem

# Recreating the SSH key
echo "Removing existing SSH key ..."
rm /config/os/root/.ssh/id_ecdsa

echo "Creating the SSH key ..."
ssh-keygen -f /config/os/root/.ssh/id_ecdsa -t ecdsa -b 256 -N ""
