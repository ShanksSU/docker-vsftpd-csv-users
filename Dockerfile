FROM fauria/vsftpd:latest

RUN mkdir -p /opt/ftp_users

COPY scripts/create_ftp_users.sh /usr/local/bin/create_ftp_users.sh
COPY scripts/entrypoint.sh      /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/create_ftp_users.sh \
    && chmod +x /usr/local/bin/entrypoint.sh

# Default FTP account
ENV FTP_USER=testuser
ENV FTP_PASS=123456

CMD ["/usr/local/bin/entrypoint.sh"]
