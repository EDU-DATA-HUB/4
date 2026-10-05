# How a page is served

This page follows **one request** from the browser through Tomcat to the database. User-facing words (portal, site, tool) are in [overview](overview.md).

Sakai runs **inside Tomcat on the host**. Docker runs **MariaDB** (all LMS data), **MongoDB** (login history only), and **Neo4j 4.0** (started for local use; Sakai code does not talk to it yet).

```mermaid
flowchart LR
  Browser["Browser<br/>:8080/portal"]
  Tomcat["Tomcat 9 + JDK 17<br/>.runtime/tomcat"]
  DB["MariaDB 10.11<br/>Docker: sakai-mariadb<br/>:3306"]
  Mongo["MongoDB 7<br/>Docker: sakai-mongodb<br/>:27017<br/>login history only"]
  Neo["Neo4j 4.0<br/>Docker: sakai-neo4j<br/>:7474 / :7687<br/>not used by Sakai yet"]

  Browser --> Tomcat --> DB
  Tomcat --> Mongo
  Neo
```

## One URL

A typical page is the **portal wrapping a tool**.

```mermaid
sequenceDiagram
  participant U as Browser
  participant P as portal.war
  participant K as Kernel / ComponentManager
  participant T as Tool WAR
  participant DB as MariaDB

  U->>P: GET /portal/site/{siteId}/tool/{placementId}
  P->>K: session, membership, permission
  P->>T: render tool inside portal layout
  T->>K: load domain data
  K->>DB: Hibernate / SQL
  DB-->>K: rows
  K-->>T: objects
  T-->>P: HTML / JS
  P-->>U: full page
```

Kernel services are registered in Spring XML under `components/*/WEB-INF/` and looked up through Sakai’s **ComponentManager**. If that Spring context fails (`SakaiApplicationContext has not been refreshed yet`), every tool fails and `/portal` shows a generic error.

## What Tomcat actually contains

A **WAR** (Web Application Archive) is one Java web module. Most UI tools compile to `*.war` under Tomcat `webapps/`. Copying WARs alone is **not** a full Sakai install. You also need components, shared libraries, `sakai.properties`, JDK, Tomcat, and the database.

```text
.runtime/tomcat/apache-tomcat-9.0.122/
  webapps/          ← tool and portal WARs (URLs)
  components/       ← kernel and service packs (not hit as URLs)
  lib/              ← shared JARs (Spring, Hibernate, MariaDB driver, …)
  sakai/            ← sakai.properties (DB URL, local flags)
  logs/catalina.out ← startup and runtime log
```

## Cache: one Tomcat

Sakai uses **Apache Ignite** as a cache. A **second** Tomcat on the same machine often fails Ignite discovery (`same hash code for partitioned affinity`) and/or bind on shutdown port **8005**. Run **one** instance: `stop.cmd` before `start.cmd`.

## Database

**Hibernate** maps Java entities to **SQL tables**. This local setup uses **MariaDB**. HSQLDB is still in the tree historically but is **not** reliable for a full boot here (Quartz `JOB_DATA` truncation). **MongoDB** is used only for login history (see [login-p12-mongodb.md](login-p12-mongodb.md)). **Neo4j 4.0** is started by `start.cmd` but not wired into Sakai. Search can use OpenSearch; local config typically has `search.enable=false`.

Next: [where this lives in the source tree](directory-structure.md).
