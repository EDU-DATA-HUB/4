# Offline kit

Compressed JDK, Maven, Tomcat, Docker images, Maven cache, and a pre-deployed Sakai Tomcat tree. These files **live in this repository** (split into parts under 90MB so GitHub accepts them).

## User flow

Download the repo as a ZIP from GitHub **or** `git clone`, then:

```bat
cd sakai
setup.cmd
start.cmd
```

Needs Docker Desktop and 7-Zip. No separate download and no GitHub Release.

## Archives

| Name | Contents |
| --- | --- |
| `01-tools.zip` (+ `.001` …) | `jdk17.zip`, `maven.zip`, `tomcat.zip` |
| `02-docker-images.zip` (+ `.001` …) | MariaDB / MongoDB / Neo4j image tars |
| `03-m2-repo.7z` (+ `.001` …) | Offline Maven repo |
| `04-tomcat-sakai.7z` (+ `.001` …) | Deployed Sakai (`webapps`, `components`, `lib`, `sakai`) |

`setup.cmd` reads a single file or the `.001` volume set.

## Maintainer

After a working deploy:

```bat
pack-offline-kit.cmd
```

Then commit everything under `offline-kit\` (including `.001` parts and `MANIFEST.txt`).
