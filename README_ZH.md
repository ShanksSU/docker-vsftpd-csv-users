# docker-vsftpd-csv-users

簡易 Docker 化的 **vsftpd** FTP 伺服器，具備：

- 預設測試帳號（`testuser`）
- 由 `user.csv` 自動建立多個 FTP 使用者

---

## 專案結構

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

## CSV 格式

`user.csv` 範例：

```csv
Username,Password
Jingliu,20231011
Lingsha,20241002
RuanMei,20231227
Firefly,20240619
```

* 第 1 欄：使用者名稱
* 第 2 欄：密碼
* 第一列標題列可有可無（若存在會被忽略）

---

## 預設帳號

在 `Dockerfile` / `docker-compose.yml` 中定義：

* **User：** `testuser`
* **Pass：** `123456`

即使 `user.csv` 不存在，也會建立此預設帳號。

---

## 執行方式

```bash
docker-compose up -d --build
docker logs vsftpd
```

Log 中應該會看到類似：

```text
Using CSV file: /opt/ftp_users/user.csv
Add user: Jingliu
...
```

---

## 連線方式（以 FileZilla 為例）

在同一台主機上：

* Host：`127.0.0.1`
* Port：`21`
* Protocol：FTP
* Encryption：Plain FTP（不加密）
* User：`testuser` 或 `user.csv` 中的任一使用者
* Password：對應的密碼或預設密碼

被動模式連接埠：**21100–21110**
若從其他機器連線，請在 `docker-compose.yml` 中將 `PASV_ADDRESS` 改為你的主機 IP。