# CraftDash

CraftDash runs the ArtCraft web applications behind one domain, with a landing page that links to each enabled app and displays its running version and availability. The dashboard checks application status every 10 seconds.

The `craft` script downloads upstream web releases of each application listed in `apps.conf`, packages them into individual Caddy container images, and generates a Docker Compose stack with Traefik routing. Each application runs in its own container and is accessible at a path such as `https://craft.example.com/photo/` for PhotoCraft, `/light/` for LightCraft, etc.

You can use the published `goodieshq` images without building anything yourself. The script will download the latest release from the `goodieshq` Docker Hub repository. If a release you want has not been published there, or you prefer to maintain your own images, use the same script with a modified `REPOSITORY` env var to build and push images to your own registry.

## Requirements

- Bash 4 or newer. On macOS, it's recommended to use a newer Bash rather than the system-provided Bash 3.2.
- Docker Engine 25 or newer and the Docker Compose plugin for the supplied images and deployment examples.
- An existing Traefik instance with Docker service discovery, an HTTPS entrypoint, and a shared frontend Docker network.
- A domain pointing to your Traefik host and a TLS certificate or certificate resolver configured in Traefik.
- **For building:** access to upstream releases.
- **For publishing:** Docker Buildx and permission to push to your chosen registry.

The generated stack does not install Traefik, create its external network, or configure DNS and certificates. The containers serve HTTP on port 8080 internally; Traefik provides HTTPS at the public endpoint.

## Use the published images

### 1. Clone the repository

```bash
git clone https://github.com/goodiesHQ/craftdash.git
cd craftdash
cp environments/example.conf environments/home.conf
# modify home.conf as needed
```

### 2. Configure your environment

Edit `environments/home.conf`. A basic configuration is:

```ini
DOMAIN=craft.example.com
REGISTRY=goodieshq
APPS=all
DEFAULT_VERSION=latest
TITLE=ArtCraft
PROJECT=craft
NETWORK=proxy
ENTRYPOINT=websecure
CERTRESOLVER=
MIDDLEWARES=
```

Use your actual domain, Traefik network, and entrypoint. Set `CERTRESOLVER` if your routers need a named Traefik certificate resolver; leave it empty if your Traefik configuration already supplies the appropriate certificate.

Keep `REGISTRY=goodieshq` to use the published Docker Hub images. This selects both the app images and `goodieshq/craft-dashboard:latest` by default. You do not need to build or push any images for this workflow.

Select apps by name or slug, separated by spaces or commas. Use `APPS=all` to enable every app in `apps.conf`.

### 3. Generate and deploy the stack

Once you have modified `home.conf` (or whatever you decided to name your environment), you can then use `craft compose` to build a `docker-compose.yml` file for it using the settings provided in the environment. All desired `APPS` will be deployed in one stack.
```bash
./craft compose environments/home.conf
docker compose -f environments/home/docker-compose.yml pull
docker compose -f environments/home/docker-compose.yml up -d --remove-orphans
```

Open the domain you configured. For the example above, the dashboard is at `https://craft.example.com/` and PhotoCraft is at `https://craft.example.com/photo/`.

Edit the `.conf` file and regenerate whenever you change the selected apps, image tags, or routing settings. The generated Compose file will be overwritten on the next generation.

To pull newer images for the tags already configured, run the `pull` and `up` commands again. The dashboard's status polling does not update containers automatically. Published `goodieshq` images may not include every upstream release; an unavailable image tag must be built or replaced with an available tag.

## Build and publish your own images

You can keep using the upstream Craft releases while publishing the resulting images under your own Docker Hub account, GHCR namespace, or other private registry. You do not need to fork the application repositories for this.

### 1. Choose a registry and sign in

Replace `dockerhubuser` with your Docker Hub username:

```bash
export REGISTRY=dockerhubuser
docker login
```

For GHCR or a private registry, use an image prefix and log in to that registry instead:

```bash
export REGISTRY=ghcr.io/username
docker login ghcr.io
```

`REGISTRY` is an image prefix, without `https://`. Examples include `dockerhubuser`, `ghcr.io/username`, and `registry.lan:5000/craft`.

### 2. Build the applications and dashboard

```bash
./craft update --push
./craft dashboard --push
```

`update --push` checks each app's latest upstream release and builds it if its version tag is missing from your registry. Newly built releases receive both a version tag and `latest`. The dashboard is built separately.

To build a single application's latest release instead:

```bash
./craft build photo --push
```

To build a specific release, supply its version. This is an example; choose a version that exists in the upstream repository:

```bash
./craft build photo 0.7.0 --push
```

An explicit version creates only that version tag unless you also pass `--latest`. Without `--push`, builds use `docker build` and remain in your local Docker image store.

### 3. Point your environment at your images

Set `REGISTRY` in your environment file to the same prefix you used for publishing:

```ini
REGISTRY=dockerhubuser
```

Then regenerate and deploy:

```bash
./craft compose environments/home.conf
docker compose -f environments/home/docker-compose.yml pull
docker compose -f environments/home/docker-compose.yml up -d --remove-orphans
```

The environment file's `REGISTRY` takes precedence over the shell variable when generating Compose. Changing only `export REGISTRY=...` will not change a configuration file that still contains `REGISTRY=goodieshq`.

You can also publish your own app images while keeping the published dashboard:

```ini
REGISTRY=dockerhubuser
DASHBOARD_IMAGE=goodieshq/craft-dashboard:latest
```

In that case, you do not need to build or publish the dashboard image.

## Command reference

Run `./craft --help` for the script's usage text. Commands accept either an app name, such as `photocraft`, or its slug, such as `photo`.

| Command | What it does |
| --- | --- |
| `./craft list` | Lists catalog entries and their latest upstream release versions. Does not check which images are published. |
| `./craft build <app> [version]` | Builds one app locally. Uses its latest upstream release when no version is supplied. |
| `./craft build all` | Builds the latest upstream release of every catalog app. |
| `./craft update` | Builds latest releases whose version tags are missing locally. |
| `./craft update --push` | Checks version tags in your registry, then builds and pushes missing releases. |
| `./craft update --force [--push]` | Builds every latest release even if its version tag already exists. |
| `./craft dashboard [--push]` | Builds the dashboard and tags it with the dashboard version and `latest`; optionally pushes it. |
| `./craft pin <app\|all> [version]` | Downloads release archives and records their SHA256 hashes in `checksums.conf`. Does not build images. `pin all` uses each app's latest release. |
| `./craft compose <env.conf> [-o directory]` | Generates `docker-compose.yml`; does not pull images or start containers. By default, `environments/home.conf` writes to `environments/home/`. |

App build options:

| Option | Effect |
| --- | --- |
| `--push` | Uses Docker Buildx to publish the image to `REGISTRY`. |
| `--latest` | Also tags the image as `latest`; automatic when building without an explicit version. |
| `--sha256 HASH` | Verifies the downloaded archive against this hash, overriding its entry in `checksums.conf`. |
| `--url URL` | Uses a different release archive URL. |

`build all` does not accept a version, `--sha256`, or `--url`. Both `build all` and `update` process the entire catalog, regardless of which apps are enabled in an environment.

Building and publishing images does not deploy them. Run Docker Compose separately to apply changes.

## Environment configuration

Environment files contain `KEY=VALUE` settings and are parsed as configuration, not executed as shell scripts. Simple quoted values and comments are supported; shell variable expansion is not performed.

| Setting | Purpose / default |
| --- | --- |
| `DOMAIN` | Required hostname for the dashboard and apps. |
| `REGISTRY` | Image prefix. Defaults to the shell's `REGISTRY`, then `goodieshq`. |
| `APPS` | App names or slugs, separated by spaces or commas; `all` enables the full catalog. Empty means dashboard only. |
| `DEFAULT_VERSION` | Default app image tag; `latest`. |
| `PHOTO_VERSION` | Per-app tag override. Use the uppercase slug or name, such as `PHOTO_VERSION` or `PHOTOCRAFT_VERSION`, but not both. |
| `PHOTO_DIGEST` | Optional per-app image digest: `sha256:` followed by 64 lowercase hexadecimal characters. Also accepts the hash without the prefix. |
| `TITLE` | Dashboard heading; `Craft`. |
| `PROJECT` | Compose project and Traefik router prefix; `craft`. Use a distinct value for each stack sharing a Traefik instance. |
| `NETWORK` | Existing external Docker network shared with Traefik; `proxy`. |
| `ENTRYPOINT` | Traefik router entrypoint; `websecure`. Generated routers enable TLS. |
| `CERTRESOLVER` | Optional Traefik certificate resolver name. |
| `MIDDLEWARES` | Optional comma-separated Traefik middlewares applied to the dashboard and all apps, such as `authentik@docker`. |
| `DASHBOARD_IMAGE` | Full dashboard image reference; defaults to `<REGISTRY>/craft-dashboard:latest`. |

Use version tags when you want to choose exactly when to upgrade an app. A per-app digest further fixes the deployed image content. Version and digest settings affect deployment; they do not build missing images.

## Release checksums

Every app build verifies its archive when a matching entry exists in `checksums.conf`. Without an entry or `--sha256`, verification is skipped unless you enable strict checking.

To record the latest releases and require checksums:

```bash
./craft pin all
# Review the releases and recorded hashes before building.
export REQUIRE_SHA256=1
./craft update --push
```

`pin` records the hash of the archive it downloads; it does not independently establish the archive's authenticity. If a pinned archive later changes, `pin` reports a mismatch and does not overwrite the existing hash.

With `REQUIRE_SHA256=1`, a single-app build without a checksum fails, while `update` skips unpinned releases. When new releases appear, review and pin them before updating. Release archive checksums and Docker image digests are different: `checksums.conf` verifies the build input; `PHOTO_DIGEST` fixes the deployed image.

## Build settings

These are shell environment variables for `craft`; they are separate from the deployment environment file.

| Variable | Default / purpose |
| --- | --- |
| `REGISTRY` | `goodieshq`; destination image prefix. |
| `PLATFORMS` | `linux/amd64`; target platforms for `--push` builds. |
| `CADDY_VERSION` | `2.11`; Caddy base image tag. |
| `REQUIRE_SHA256` | `0`; set to `1` to require pinned release archives. |
| `GITHUB_TOKEN` | Optional token for latest-release lookup through the GitHub API. |
| `ICON_URL` | `https://getartcraft.com/images/apps/{name}/icon.webp`; dashboard icon URL pattern. |

For example, publish AMD64 and ARM64 images with a Buildx builder capable of building both platforms:

```bash
export PLATFORMS=linux/amd64,linux/arm64
./craft update --push
./craft dashboard --push
```

The included `update_and_push.sh` sets its own registry and build variables. Edit those values before using it to publish under your account. It requires pinned release checksums.

## Change the application catalog

`apps.conf` defines the image names, URL paths, dashboard labels, and upstream release sources:

```text
# name       slug   title       GitHub repository      optional asset pattern
photocraft   photo  PhotoCraft  storytold/photocraft
```

The default archive URL is:

```text
https://github.com/<owner>/<repo>/releases/download/v<version>/<name>-web-<version>.zip
```

Set the optional fifth column to another archive filename or a complete URL. It supports `{name}` and `{version}` placeholders. Catalog columns are whitespace-separated, so titles must not contain spaces.

Change the GitHub repository column if you want to build releases from your own application fork. Changing `REGISTRY` alone changes where container images are stored; it does not change which application source is downloaded. Release archives must contain an application directory with `index.html` in the layout expected by `app/fetch.sh`.

The catalog currently includes PhotoCraft, VectorCraft, FilmCraft, LightCraft, PDFCraft, EffectCraft, DesignCraft, WordCraft, DeckCraft, GridCraft, CADCraft, and SoundCraft. Upstream applications are maintained in the [storytold GitHub repositories](https://github.com/storytold).

## Dashboard changes

Rebuild the dashboard image when changing `dashboard/index.html`, its Caddy configuration, or its bundled icons:

```bash
./craft dashboard --push
docker compose -f environments/home/docker-compose.yml pull dashboard
docker compose -f environments/home/docker-compose.yml up -d dashboard
```

Changing enabled apps or their configured tags only requires regenerating Compose and applying it. Status polling displays availability and the version reported by each running app; it does not refetch the app catalog, pull images, or deploy new releases.
