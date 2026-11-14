---
name: octodoctor-report
description: Locate or download the `octodoctor` binary, run it against a directory of Argo CD manifests or export live resources from a Kubernetes cluster's Argo CD install and analyze those, then summarize the resulting best-practices report (pass/fail/inactive rules, severities, doc links) and point to the generated HTML report. Use this whenever the user asks to analyze, audit, review, or health-check an Argo CD installation, cluster, namespace or manifest directory against best practices — including phrases like "check my Argo CD setup", "run octodoctor", "audit my Argo CD cluster", "is my Argo CD config following best practices", "scan these Argo CD manifests", or "export Argo CD from context X and analyze it" — even when the user never says "octodoctor" by name.
compatibility: Requires curl and tar (PowerShell on Windows) and network access to github.com, unless octodoctor is already on PATH.
---

# octodoctor best-practices report

`octodoctor` is a static analyzer for Argo CD manifests (Applications, ApplicationSets, AppProjects,
the `argocd-*` ConfigMaps, and cluster Secrets). It never mutates anything — the only network-facing
part is `--export`, which reads resources out of a live cluster and writes them to disk before the
same file-based analysis runs on them.

This skill has two entry points. Pick based on what the user actually has:

- **A directory of manifests already on disk** → directory mode (`-d`).
- **A running cluster** they want checked → export mode (`-e`), which pulls the manifests first.

Don't ask the user to pick a mode explicitly if their request already implies one ("check this folder"
vs. "check my cluster") — infer it and confirm briefly if genuinely ambiguous.

## Step 1: locate or download the binary

1. **Already installed.** Run `octodoctor --version`. If it works, use `octodoctor` as is.

2. **Download the latest release.** Otherwise run the block below as a single shell command. It
   resolves the latest tag from https://github.com/OctopusDeploy/octodoctor-argocd/releases (by
   following the `releases/latest` redirect, so there's no GitHub API rate limit), downloads the
   archive for this OS and CPU, verifies it against the release's `checksums.txt`, and extracts the
   binary into the temp directory. A second run reuses the binary it already extracted. On a checksum
   mismatch it exits non-zero without extracting anything — never run a binary that failed the check.
   Downloading from the official releases page is expected, so don't ask for permission first.

   ```sh
   set -eu
   repo=OctopusDeploy/octodoctor-argocd
   tag=$(basename "$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")")
   case "$(uname -s)" in Linux) os=linux ;; Darwin) os=darwin ;; *) echo "unsupported OS: $(uname -s)" >&2; exit 1 ;; esac
   case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; esac
   dest="${TMPDIR:-/tmp}/octodoctor-$tag"
   if [ ! -x "$dest/octodoctor" ]; then
     asset="octodoctor_${tag#v}_${os}_${arch}.tar.gz"
     work=$(mktemp -d)
     if command -v sha256sum >/dev/null; then sum=sha256sum; else sum="shasum -a 256"; fi
     curl -fsSL -o "$work/$asset" "https://github.com/$repo/releases/download/$tag/$asset"
     curl -fsSL -o "$work/checksums.txt" "https://github.com/$repo/releases/download/$tag/checksums.txt"
     (cd "$work" && grep " $asset\$" checksums.txt | $sum -c -)
     mkdir -p "$dest" && tar -xzf "$work/$asset" -C "$dest" octodoctor && rm -rf "$work"
   fi
   "$dest/octodoctor" --version && echo "$dest/octodoctor"
   ```

   On Windows, run this in PowerShell instead. Only an amd64 build is published; Windows on ARM runs it
   under emulation.

   ```powershell
   $ErrorActionPreference = 'Stop'
   $repo = 'OctopusDeploy/octodoctor-argocd'
   $tag = Split-Path -Leaf ([System.Net.HttpWebRequest]::Create("https://github.com/$repo/releases/latest").GetResponse().ResponseUri.AbsolutePath)
   $dest = Join-Path $env:TEMP "octodoctor-$tag"
   $exe = Join-Path $dest 'octodoctor.exe'
   if (-not (Test-Path $exe)) {
     $asset = "octodoctor_$($tag.TrimStart('v'))_windows_amd64.zip"
     $work = Join-Path $env:TEMP ([guid]::NewGuid())
     New-Item -ItemType Directory $work | Out-Null
     Invoke-WebRequest -UseBasicParsing "https://github.com/$repo/releases/download/$tag/$asset" -OutFile "$work\$asset"
     Invoke-WebRequest -UseBasicParsing "https://github.com/$repo/releases/download/$tag/checksums.txt" -OutFile "$work\checksums.txt"
     $expected = (Select-String -Path "$work\checksums.txt" -Pattern " $asset$").Line.Split(' ')[0]
     if ((Get-FileHash "$work\$asset" -Algorithm SHA256).Hash -ne $expected) { throw "checksum mismatch for $asset" }
     Expand-Archive "$work\$asset" $work
     New-Item -ItemType Directory -Force $dest | Out-Null
     Move-Item "$work\octodoctor.exe" $exe
     Remove-Item -Recurse $work
   }
   & $exe --version
   $exe
   ```

   The last line printed is the absolute path of the binary. Use that full path for every later
   command, and tell the user which version you used and where it is.

3. If the download fails (no network, the sandbox blocks github.com, or an unsupported platform), stop.
   Tell the user what went wrong and that they can download a binary themselves from the releases page
   and put it on `PATH`.

In the steps below, `octodoctor` means whichever binary you resolved here.

## Step 2: directory mode

```
octodoctor -d <path-to-manifests>
```

Defaults to `.` (cwd) if `-d` is omitted. The directory must already exist. Never pass `--export`,
`--context`, or `--namespace` alongside `-d` — the tool refuses `-d` combined with `-e`, and silently
ignores `-c`/`-n` without `-e` set (with a warning), so mixing them just confuses the run.

## Step 3: cluster export mode

```
octodoctor -e -c <kube-context> -n <namespace>
```

- `-c/--context` defaults to whatever `kubectl config current-context` currently resolves to. Only
  ask the user which context to use if there are multiple plausible candidates (e.g. they mentioned a
  cluster name that doesn't match the current context) — otherwise just use the current one and say
  which one you used.
- `-n/--namespace` defaults to `argocd`. Only ask if the user's Argo CD is known to live somewhere else.
- This talks to a real cluster over the network and needs a working kubeconfig — if `kubectl` can't
  reach the cluster or the sandbox blocks the connection, report that plainly rather than working
  around it.
- Export only *reads* the five Argo CD resource kinds via `kubectl`/client-go; it writes them to a
  local `argocd-manifests-export-<context>/` directory. Secret **values** are replaced with a
  placeholder before analysis ever sees them — only key names are kept, because that's all the rules
  need. It's safe to mention this to the user if they're wondering whether secrets get exposed.
- A pre-existing export directory with the same name is deleted and recreated — if the user has one
  they care about from a previous run they want to keep, warn them before re-running.

## Step 4: run it and read the exit code

`octodoctor` exits **1** if any rule failed, **0** otherwise (with the default `--fail-on medium`;
`--fail-on high` only counts high severity failures and `--fail-on none` always exits 0 — you don't
need to pass it, since the report lists every failure regardless). A nonzero exit is expected, normal output for a
real installation — it is not a tool failure and you should not treat a nonzero exit code as an error
to work around. Just proceed to reading the report either way.

The report lands in `<target-directory>/octodoctor-output/`:
- `index.html` — the report the user will actually want to view.
- `report.json` — same data, structured, for you to summarize from.
- `report.yaml` — same data again, YAML.

(`<target-directory>` is the `-d` path in directory mode, or the export directory `octodoctor` printed
in export mode.)

## Step 5: summarize the report

Read `<target-directory>/octodoctor-output/report.json`. If `jq` is available, this prints only the
parts you need, with failed rules sorted by severity and affected files capped at five per rule:

```sh
jq '{version: .metadata.version, rules: .summary.rules, resources: .summary.resources,
  failed: [.results.failed | sort_by({"high":0,"medium":1,"low":2}[.severity]) | .[]
    | {severity, id, name, description, documentationUrl, files: .affectedFiles[:5],
       moreFiles: ([(.affectedFiles | length) - 5, 0] | max)}]}' <target-directory>/octodoctor-output/report.json
```

Without `jq`, read the file directly and use the same fields: `metadata.version`,
`summary.rules.{total,failed,passed,inactive}`, `summary.resources`, and for each entry in
`results.failed` its `severity`, `id`, `name`, `description`, `affectedFiles` and `documentationUrl`.
Ignore `results.passed` and `results.inactive` beyond their counts.

Write a short summary in chat: total rules failed/passed/inactive, then the failed rules ordered by
severity (high, medium, low) with what they mean, which files triggered them (at most five per rule,
plus how many more) and the doc link.

Then tell the user where `index.html` is so they can open it themselves — this skill doesn't need a
browser to do its job, so don't try to open one unless the user separately asks you to. If they ask
"can you fix these", switch to actually editing the flagged manifests to address the failures, but
don't do that unprompted.
