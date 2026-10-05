# PKCS#12 login and MongoDB login history

This checkout adds two local features. Everything else (users, sites, content, Sakai events) stays in **MariaDB**.

| Feature | Where |
| --- | --- |
| Username / password login | Unchanged (MariaDB users) |
| `.p12` certificate login | Login page upload |
| Login history (success + failure) | **MongoDB** only |

## Enable

In `.runtime/tomcat/apache-tomcat-9.0.122/sakai/sakai.properties`:

```properties
login.p12.enabled=true
login.p12.truststore.path=${sakai.home}p12-trust.jks
login.p12.truststore.password=changeit
login.p12.identity.attribute=cn

login.history.mongodb.enabled=true
login.history.mongodb.uri=mongodb://127.0.0.1:27017
login.history.mongodb.database=sakai
login.history.mongodb.collection=login_history
```

`start.cmd` loads the bundled Docker images from `.runtime/downloads/` (same offline pattern as MariaDB: `mongo-7.tar`), starts MariaDB, then MongoDB (`sakai-mongodb` on `127.0.0.1:27017`), then Tomcat. `stop.cmd` stops all three. You do not install MongoDB on Windows.

## Demo certificate (CN = admin)

From the project root (cmd.exe):

```bat
create-p12-demo.cmd
```

That writes:

- Truststore: `.runtime/tomcat/.../sakai/p12-trust.jks`
- Sample file: `.runtime/p12-demo/admin.p12`
- Passphrase: `changeit`
- Certificate **CN=admin** (matches the demo Sakai user)

Restart Tomcat after creating the files if Sakai is already running.

## How to log in

1. Open http://localhost:8080/portal and click **Login** (goes to `/portal/xlogin`)
2. Sign in with username/password, **or** use **Certificate login (.p12)** below that form
3. For the demo cert: `.runtime\p12-demo\admin.p12`, passphrase `changeit`

Both password and certificate attempts (success and failure) are written to MongoDB.

The cert must be signed by a CA in the truststore. The identity (CN by default) must match an existing Sakai eid.

## Query login history

```bat
docker exec -it sakai-mongodb mongosh sakai --eval "db.login_history.find().sort({timestamp:-1}).limit(20).pretty()"
```

Each document has: `timestamp`, `eid`, `userId`, `ip`, `method` (`password` or `p12`), `success`, `failReason`, `userAgent`.

Failed password and failed certificate attempts are recorded as well. If MongoDB is down, login still works; history writes are best-effort.

## Code map

| Piece | Path |
| --- | --- |
| Login UI | `login/login-render-engine-impl/.../xlogin.vm` |
| Upload handler | `login/login-tool/.../SkinnableLogin.java` |
| PKCS#12 validation | `login/login-impl/.../P12CertificateServiceImpl.java` |
| History API / Mongo writer | `login-history/` |
