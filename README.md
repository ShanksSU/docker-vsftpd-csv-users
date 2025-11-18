# docker-vsftpd-csv-users

Simple Dockerized **vsftpd** FTP server with:

- One default test account (`testuser`)
- Auto-create multiple FTP users from `user.csv`
---

## Structure

```text
.
├─ Dockerfile
├─ docker-compose.yml
├─ user.csv
├─ scripts/
│  ├─ entrypoint.sh
│  └─ create_ftp_users.sh
└─ ftpdata/
````

---

## CSV format

`user.csv` example:

```csv
Username,Password
Jingliu,20231011
Lingsha,20241002
RuanMei,20231227
Firefly,20240619
```

* 1st column: username
* 2nd column: password
* Header row is optional (will be ignored)

---

## Default account

Defined in `Dockerfile` / `docker-compose.yml`:

* **User:** `testuser`
* **Pass:** `123456`

Created even if `user.csv` is missing.

---

## Run

```bash
docker-compose up -d --build
docker logs vsftpd
```

Log should show lines like:

```text
Using CSV file: /opt/ftp_users/user.csv
Add user: Jingliu
...
```

---

## Connect (FileZilla example)

On the same host:

* Host: `127.0.0.1`
* Port: `21`
* Protocol: FTP
* Encryption: Plain FTP
* User: `testuser` or any CSV user
* Password: from `user.csv` or default

Passive mode ports: **21100–21110**
If connecting from another machine, set `PASV_ADDRESS` in `docker-compose.yml` to your host IP.