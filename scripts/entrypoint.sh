#!/bin/bash
set -e

echo "Starting vsftpd..."

/usr/sbin/run-vsftpd.sh &

VSFTPD_WRAPPER_PID=$!

sleep 3

echo "Running create_ftp_users.sh ..."

if [ -x /usr/local/bin/create_ftp_users.sh ]; then
    /usr/local/bin/create_ftp_users.sh
else
    echo "create_ftp_users.sh not found or not executable, skipping."
fi

echo "Setup complete. Waiting for vsftpd to stay running..."

wait "$VSFTPD_WRAPPER_PID"
