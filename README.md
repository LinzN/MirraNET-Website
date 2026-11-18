# MirraNET website

Source of [mirranet.de](https://mirranet.de), the home page of MirraNET – the system behind [STEM](https://github.com/LinzN/Stem) and [Mirra](https://github.com/LinzN/mirra), [FreeX](https://github.com/FreeX-Studio), [Ondura](https://github.com/Ondura-Suite), [Parla](https://github.com/Parla-Studio) and the libraries under [LinzN](https://github.com/LinzN). Plain HTML, CSS and a little JavaScript, in English and German – no framework, no external requests from the visitor's browser. Built the same way as the [FreeX](https://github.com/FreeX-Studio/FreeX-Website) and [Ondura](https://github.com/Ondura-Suite/Ondura-Website) websites.

## Languages

English is the default and lives at the root (`/`), German under `/de/`. Both are rendered from the same templates in `src/pages/`, where each text holds both languages side by side:

```html
<h2>{{de}}Die Projekte{{en}}The projects{{/}}</h2>
```

[`scripts/build.py`](scripts/build.py) (Python standard library only) renders `src/` into `site/`. The supported placeholders are documented at the top of the script.

Which language a visitor gets:

1. An explicit choice from the DE/EN switcher in the header wins. It is kept in `localStorage` (`mirranet-lang`), nothing else is stored.
2. Otherwise the browser's preferred language decides: German (`de-*`) gets `/de/`, everything else gets English.
3. German pages never redirect a visitor who hasn't chosen, so shared `/de/` links stay German.

## How it stays in sync

The MirraNET mark, the STEM icon and the social preview live in this repository (`src/static/assets/brand/`). Everything about the other projects comes from their own repositories every time the site is deployed:

| What | Source | Lands in |
| --- | --- | --- |
| FreeX icon | [Freex-Media-Server](https://github.com/FreeX-Studio/Freex-Media-Server) `docs/brand/freex-app-icon.svg` | `site/assets/brand/freex.svg` |
| Ondura icon | [Ondura-Core](https://github.com/Ondura-Suite/Ondura-Core) `apps/ondura/public/ondura.svg` | `site/assets/brand/ondura.svg` |
| Parla icon | [parla](https://github.com/Parla-Studio/parla) `docs/logo.svg` | `site/assets/brand/parla.svg` |
| Latest release, language and last activity of every listed repository | GitHub API | `site/projects.json` |

A missing icon is reported in the build log and replaced by the MirraNET mark, so a renamed file in one project never breaks the site. The list of repositories is at the top of [`scripts/sync-projects.sh`](scripts/sync-projects.sh); a new project needs an entry there and a card in `src/pages/index.html`.

The workflow [`deploy.yml`](.github/workflows/deploy.yml) builds the pages, runs the sync script and publishes `site/` to GitHub Pages:

- on every push to `main`,
- every six hours (picks up new releases and icons automatically),
- manually via *Actions › Deploy website › Run workflow*,
- on a `repository_dispatch` event of type `project-updated`.

## One-time setup

1. **Pages:** *Settings › Pages › Build and deployment › Source:* **GitHub Actions**.
2. **Custom domain:** *Settings › Pages › Custom domain:* `mirranet.de`, then tick *Enforce HTTPS* once the certificate is issued.
3. **DNS (Hetzner),** in the `mirranet.de` zone – `mirranet.de` is an apex domain, so it needs A/AAAA records instead of a CNAME:

   ```
   @     A      185.199.108.153
   @     A      185.199.109.153
   @     A      185.199.110.153
   @     A      185.199.111.153
   @     AAAA   2606:50c0:8000::153
   @     AAAA   2606:50c0:8001::153
   @     AAAA   2606:50c0:8002::153
   @     AAAA   2606:50c0:8003::153
   www   CNAME  linzn.github.io.
   ```

   Replace the existing A/AAAA records of `@` – leave `MX`, `TXT` (SPF, DKIM, DMARC) and all subdomains (`builds`, `apt`, `freex`, `ondura`, the mail host …) untouched. If the `MX` record points at `mirranet.de` itself rather than a host name like `mail.mirranet.de`, give the mail server its own A record first and point `MX` there, otherwise mail would go to GitHub.
4. Optional – **verify the domain** (*GitHub › Settings › Pages › Add a domain*) so nobody else can claim it. GitHub shows a TXT record to add at Hetzner.

### Optional: deploy immediately after a release

To update the site the moment a project publishes a release, add a step to its release workflow (or Jenkins job) using a fine-grained token with *Contents: read & write* on this repository:

```sh
curl -fsSL -X POST \
  -H "Authorization: Bearer $WEBSITE_DISPATCH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/LinzN/MirraNET-Website/dispatches \
  -d '{"event_type":"project-updated"}'
```

## Local preview

```sh
mkdir -p .projects
git clone --depth 1 https://github.com/FreeX-Studio/Freex-Media-Server.git .projects/freex
git clone --depth 1 https://github.com/Ondura-Suite/Ondura-Core.git .projects/ondura
git clone --depth 1 https://github.com/Parla-Studio/parla.git .projects/parla
python3 scripts/build.py
scripts/sync-projects.sh .projects site      # needs bash 4+, curl and jq
python3 -m http.server -d site 8080
```

## Layout

```
src/
  pages/              index, legal (Impressum), privacy (Datenschutz) – both languages
  partials/           head (language detection), header (with DE/EN switch), footer
  static/             copied as-is: CSS, JS, brand, font (Outfit, SIL OFL 1.1), 404, CNAME
scripts/
  build.py            renders src/ into site/ (en at /, de at /de/)
  sync-projects.sh    adds the project icons and projects.json
site/                 build output, not committed
```

| Page | English | German |
| --- | --- | --- |
| Home | `/` | `/de/` |
| Legal notice | `/legal-notice.html` | `/de/impressum.html` |
| Privacy | `/privacy.html` | `/de/datenschutz.html` |

## License

The website code is licensed under the [GNU Lesser General Public License v3.0](https://www.gnu.org/licenses/lgpl-3.0.html). The Outfit font is licensed under the SIL Open Font License 1.1 (`src/static/assets/fonts/OFL.txt`).
