# Setup and Running Guide

This file is **how to set up, start, stop, and rebuild** on Windows. What the project is, how a request is served, the source tree, and versions: [docs/README.md](docs/README.md).

Use **Command Prompt (cmd.exe)** in this project folder. Git Bash also works: the scripts call Windows `timeout` / `netstat` from `System32` so they do not pick up Git’s `timeout`.

**Requirements on the PC:** Docker Desktop, a code IDE (optional), and **7-Zip** (`7z` on PATH) for `setup.cmd`. You do **not** install JDK, Maven, Tomcat, MariaDB, MongoDB, or Neo4j on Windows — those are in `offline-kit\` inside this repo (or Docker images loaded from it).

---

## 0. First-time setup (download/clone → setup → start)

On the PC: **Docker Desktop** and **7-Zip**. No JDK/Maven/Tomcat/DB install.

**Option A — ZIP from GitHub:** Code → Download ZIP → unzip, then:

```bat
cd sakai
setup.cmd
start.cmd
```

**Option B — git clone:**

```bat
git clone <this-repo-url>
cd sakai
setup.cmd
start.cmd
```

`setup.cmd` only unpacks `offline-kit\` from this repo into `.runtime\`. No extra download. Use `setup.cmd /force` to overwrite an existing `.runtime\`.

### Maintainer: refresh offline-kit

On a machine that already has a working `.runtime\` (after a successful deploy):

```bat
pack-offline-kit.cmd
```

Commit the files under `offline-kit\` (archives are split under 90MB for GitHub’s file-size limit).

---

## 1. Start the project

1. Start Docker Desktop and wait until it is running.
2. Open cmd.exe and go to this folder:

```bat
cd /d C:\path\to\sakai
```

3. Start the databases and Tomcat:

```bat
start.cmd
```

`start.cmd` loads Docker images from `.runtime\downloads\` if needed, starts **MariaDB**, **MongoDB** (login history), and **Neo4j 4.0** (runtime only — Sakai does not use it yet), then Tomcat.

4. In a **second** cmd window in this folder, follow the log. Do not open the browser yet:

```bat
logs.cmd
```

Wait until this line appears (often **5–10 minutes** the first time):

```text
Server startup in [......] milliseconds
```

Ctrl+C in that window stops the log viewer only. Tomcat keeps running.

5. Open http://localhost:8080/portal  
   - Password login: **admin** / **admin** (click **Login** in the header first)  
   - Certificate login: see [§2 Certificate login (.p12)](#2-certificate-login-p12) below  

Do not run `start.cmd` again while it is already running.

---

## 2. Certificate login (.p12)

### Current demo files

| Item | Value |
| --- | --- |
| Key file | `.runtime\p12-demo\admin.p12` |
| Passphrase | `changeit` |
| Certificate CN | `admin` (must match a Sakai username / eid) |
| Truststore | `.runtime\tomcat\apache-tomcat-9.0.122\sakai\p12-trust.jks` |

### How to log in with the .p12

1. Open http://localhost:8080/portal and click **Login**.
2. On the login page, use **Certificate login (.p12)** under the password form.
3. Choose `.runtime\p12-demo\admin.p12`, enter passphrase `changeit`, then **Log in with certificate**.

### Create or recreate the demo .p12

From this project folder (cmd.exe):

```bat
create-p12-demo.cmd
```

That regenerates the truststore and `admin.p12` with passphrase **`changeit`**. Restart Tomcat afterward if Sakai is already running (`stop.cmd` then `start.cmd`).

### Create a new .p12 (different user or passphrase)

1. The certificate **CN** must match an existing Sakai eid (for example `admin`, or another user you created).
2. Edit `create-p12-demo.cmd`:
   - `PASS=...` — your passphrase (used for the `.p12` and the truststore)
   - `USER_P12=...` — output file name (for example `myuser.p12`)
   - `-dname "CN=..."` — set `CN=` to that Sakai eid
3. Run `create-p12-demo.cmd` again, then restart Tomcat.
4. Log in with the new file and the passphrase you set in `PASS`.

More detail: [docs/login-p12-mongodb.md](docs/login-p12-mongodb.md).

### Neo4j 4.0 (optional runtime only)

`start.cmd` also starts Neo4j. **Sakai does not use it yet** — it is only available for you to explore.

| Item | Value |
| --- | --- |
| Browser | http://127.0.0.1:7474 |
| Bolt | `bolt://127.0.0.1:7687` |
| User | `neo4j` |
| Password | `sakai` |
| Image tar | `.runtime\downloads\neo4j-4.0.tar` |

---

## 3. Stop the project

```bat
stop.cmd
```

If http://localhost:8080 is still in use:

```bat
netstat -ano | findstr ":8080"
taskkill /PID <pid> /F
```

Then you may run `start.cmd` again.

---

## 4. Rebuild after you change code

1. Load the bundled Java 17:

```bat
call env.cmd
java -version
```

The version must be **17**.

2. Full rebuild and restart:

```bat
stop.cmd
build.cmd
start.cmd
```

3. Rebuild only one module (example: assignments), then restart:

```bat
call env.cmd
stop.cmd
mvn -Dmaven.repo.local="%M2_REPO%" -DskipTests -Dmaven.tomcat.home="%CATALINA_HOME%" -Dsakai.home="%SAKAI_HOME%" clean install sakai:deploy -pl assignment -am
start.cmd
```

Change `-pl assignment` to the folder you edited (`portal`, `gradebookng`, `kernel`, …).

---

## 5. Commands in this folder

| File | What it does |
| --- | --- |
| `setup.cmd` | Unpack `offline-kit\` into `.runtime\` |
| `pack-offline-kit.cmd` | Build `offline-kit` archives from a working `.runtime\` (maintainer) |
| `start.cmd` | Load DB images if needed; start MariaDB, MongoDB, Neo4j, Tomcat |
| `logs.cmd` | Print `catalina.out` as it grows, with colors (Ctrl+C to stop viewing) |
| `stop.cmd` | Stop Tomcat, MariaDB, MongoDB, and Neo4j |
| `build.cmd` | Compile and deploy into Tomcat |
| `env.cmd` | Use Java/Maven from `.runtime\` (`call env.cmd`) |
| `create-p12-demo.cmd` | Create truststore + sample `admin.p12` for certificate login |

---

## 6. If it does not work

1. If `.runtime\jdk` or Tomcat is missing, run `setup.cmd` (needs `offline-kit\` from this repo and 7-Zip).
2. Run `logs.cmd`, or read `.runtime\tomcat\apache-tomcat-9.0.122\logs\catalina.out` (the web page often only says “unexpected error”).
3. Run `docker ps` and check that `sakai-mariadb`, `sakai-mongodb`, and `sakai-neo4j` are Up.
4. Do not start Tomcat twice. Always `stop.cmd` first.
5. Confirm `.runtime\downloads\mariadb-10.11.tar`, `mongo-7.tar`, and `neo4j-4.0.tar` are present, then run `start.cmd` again.
6. If `build.cmd` fails on missing Maven jars, `.runtime\m2` must be present (re-run `setup.cmd` from a full kit).

## 7. What this project is

Start at [docs/README.md](docs/README.md), then:

1. [docs/overview.md](docs/overview.md) — LMS in the browser: portal, sites, tools
2. [docs/architecture.md](docs/architecture.md) — one request through Tomcat to MariaDB
3. [docs/directory-structure.md](docs/directory-structure.md) — platform folders vs tools
4. [docs/versions.md](docs/versions.md) — 27-SNAPSHOT, JDK 17, Tomcat 9, MariaDB 10.11
5. [docs/login-p12-mongodb.md](docs/login-p12-mongodb.md) — `.p12` login and MongoDB login history
