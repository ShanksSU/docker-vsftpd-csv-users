#!/bin/bash
set -e

VIRTUAL_USERS_FILE="/etc/vsftpd/virtual_users.txt"
VIRTUAL_USERS_DB="/etc/vsftpd/virtual_users.db"

# Show files under /opt/ftp_users
echo "Listing /opt/ftp_users:"
ls -l /opt/ftp_users || echo "/opt/ftp_users not found"

CSV_FILE=""

# Find CSV file
if [ -f "/opt/ftp_users/user.csv" ]; then
    CSV_FILE="/opt/ftp_users/user.csv"
fi

echo "==============================="
echo "FTP_USER: ${FTP_USER:-testuser}"
echo "CSV_FILE: ${CSV_FILE:-none}"

# Write default account (testuser)
DEFAULT_USER="${FTP_USER:-testuser}"
DEFAULT_PASS="${FTP_PASS:-123456}"

# Reset virtual_users.txt with default user
echo "Generating ${VIRTUAL_USERS_FILE}..."
printf "%s\n%s\n" "$DEFAULT_USER" "$DEFAULT_PASS" > "${VIRTUAL_USERS_FILE}"

# Ensure home dir for default user
if [ ! -d "/home/vsftpd/${DEFAULT_USER}" ]; then
    mkdir -p "/home/vsftpd/${DEFAULT_USER}"
fi
chown -R ftp:ftp "/home/vsftpd/${DEFAULT_USER}"

# If user.csv exists, add more users from it
if [ -n "$CSV_FILE" ]; then
    echo "Using CSV file: $CSV_FILE"

    # Check if first line is header (Username,Password)
    HEADER_LINE=$(head -n 1 "$CSV_FILE" | tr -d '\r\n')

    if echo "$HEADER_LINE" | grep -qi "Username"; then
        START_LINE=2  # Has header, start from line 2
    else
        START_LINE=1  # No header, start from line 1
    fi

    # Read CSV: first column = username, second = password
    tail -n +"$START_LINE" "$CSV_FILE" | tr -d '\r' | while IFS=, read -r student_number password; do
        # Skip empty lines
        if [ -z "$student_number" ] || [ -z "$password" ]; then
            continue
        fi

        # Trim spaces
        student_number=$(echo "$student_number" | xargs)
        password=$(echo "$password" | xargs)

        echo "Add user: $student_number"

        # Append user and password to virtual_users.txt
        printf "%s\n%s\n" "$student_number" "$password" >> "${VIRTUAL_USERS_FILE}"

        # Create home dir for this user
        if [ ! -d "/home/vsftpd/${student_number}" ]; then
            mkdir -p "/home/vsftpd/${student_number}"
        fi
        chown -R ftp:ftp "/home/vsftpd/${student_number}"
    done
else
    echo "No user.csv found. Only default user will be created."
fi

# Build Berkeley DB for virtual users
echo "Generating virtual users DB: ${VIRTUAL_USERS_DB}..."
/usr/bin/db_load -T -t hash -f "${VIRTUAL_USERS_FILE}" "${VIRTUAL_USERS_DB}"

echo "Done creating FTP users."