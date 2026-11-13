"""Part of hook-refaktor.sh (claude-config #58, review r1 F1/F7): the supervisor's directory by real path.

stdin: the PreToolUse JSON (tool_name, tool_input, cwd). env NADZOR_GLOBY: the --nadzor globs, one per line; a relative
one is taken from the main checkout (`git rev-parse --git-common-dir` of cwd), as the gate's {REPO}.
stdout, line 1: `BLOK<TAB><reason>` | `OK` | `NIEZNANE` (no root resolved: the caller falls back to literal globs);
then, for Bash, the command with variables assigned in it expanded (the caller's literal checks of the measure use it).
A path counts by its real path against cwd and every `cd`/`pushd`/`git -C` target of the command, so `../../tmp/…`
from a worktree under {REPO}/.claude/worktrees, a symlink to the directory and `cd` into a parent are the directory.
Blocked: Write/Edit into it; a redirect into it; a writer (cp, mv, rm, ln, tee, sed -i, git checkout, find -delete,
xargs <writer>, an interpreter or script — inline code, a heredoc or a script file whose text names it) with an argument
in it; `ln`, `rm`, `mv`, `cp`, `rsync` on one of its ancestors (outside the session's own cwd); `$(…)`/backticks naming it
in a command that writes. Reads (cat, grep, jq, a checker's output to a file elsewhere) pass.
The hook is a fence for an honest executor's slips and lazy shortcuts, not a sandbox: the OS-level fence is the session's
permissions (cykl-refaktoru.md, krok 1).
"""
import glob, json, os, re, shlex, subprocess, sys

dane = json.loads(sys.stdin.read() or "{}")
narz = dane.get("tool_name") or ""
wej = dane.get("tool_input") or {}
cwd = dane.get("cwd") or os.getcwd()
globy = [g.strip() for g in os.environ.get("NADZOR_GLOBY", "").splitlines() if g.strip()]

cmd = wej.get("command") or ""
# Variables assigned in the command itself (`D=…; … $D/x`, `export D=…`), $HOME and $PWD are expanded.
for m in re.finditer(r"(?:^|[;&|\s])(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(\"[^\"]*\"|'[^']*'|[^;&|\s]*)", cmd):
    v = m.group(2)
    if v[:1] in "\"'":
        v = v[1:-1]
    cmd = re.sub(r"\$\{" + m.group(1) + r"\}|\$" + m.group(1) + r"(?![A-Za-z0-9_])", lambda _: v, cmd)
for k, v in (("HOME", os.environ.get("HOME", "")), ("PWD", cwd)):
    cmd = re.sub(r"\$\{" + k + r"\}|\$" + k + r"(?![A-Za-z0-9_])", lambda _: v, cmd)


def wyjdz(werdykt):
    sys.stdout.write(werdykt + "\n" + (cmd if narz == "Bash" else "") + "\n")
    sys.exit(0)


def glowne_repo(d):
    r = subprocess.run(["git", "-C", d, "rev-parse", "--path-format=absolute", "--git-common-dir"],
                       capture_output=True, text=True)
    return os.path.dirname(r.stdout.strip()) if r.returncode == 0 and r.stdout.strip() else None


korzenie, repo = [], None
for g in globy:
    lit = g.split("*")[0].rstrip("/")
    if not lit:
        continue
    if os.path.isabs(lit):
        korzenie.append(os.path.realpath(lit))
    else:
        repo = repo or glowne_repo(cwd)
        if repo:
            korzenie.append(os.path.realpath(os.path.join(repo, lit)))
if not korzenie:
    wyjdz("NIEZNANE")


def rp(p, baza):
    return os.path.realpath(os.path.join(baza, os.path.expanduser(p)))


# Compared case-folded: APFS and NTFS ignore letter case, so `../../TMP/Refaktor/…` is the directory (r2 F12); on a
# case-sensitive volume this only adds a refusal for a look-alike name.
KORZ = [k.casefold() for k in korzenie]


def w(x):  # x is the directory or inside it
    x = x.casefold()
    return any(x == k or x.startswith(k + "/") for k in KORZ)


def przodek(x):  # x is a proper ancestor of the directory
    x = x.casefold()
    return x != "/" and any(k.startswith(x.rstrip("/") + "/") for k in KORZ)


CWD = os.path.realpath(cwd)

if narz in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    p = wej.get("file_path") or wej.get("notebook_path") or ""
    if p and w(rp(p, CWD)):
        wyjdz("BLOK\t" + p)
    wyjdz("OK")
if narz != "Bash":
    wyjdz("OK")

# ---- Bash ------------------------------------------------------------------------------------------------------------
PISZACE = {"cp", "mv", "install", "ln", "rsync", "dd", "truncate", "touch", "rm", "unlink", "mkdir", "rmdir", "patch",
           "tee", "sponge", "chmod", "chown", "shred", "curl", "wget", "tar", "unzip", "cpio", "ed", "ex", "vi", "vim"}
INTERP = re.compile(r"^(python[0-9.]*|php[0-9.]*|node|ruby|perl|deno|bun|bash|sh|zsh|dash|ksh|awk|gawk|eval|source|\.)$")
PRZODKOWE = {"ln", "rm", "mv", "cp", "rsync"}
PREFIKSY = {"sudo", "env", "command", "nohup", "time", "exec", "nice", "caffeinate", "builtin"}
SEP = {";", "&&", "||", "|", "&", "|&", "(", ")", "\n", ";;"}

try:
    lx = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lx.whitespace_split = True
    lx.commenters = ""
    tokeny = list(lx)
except ValueError:
    tokeny = [t.strip("\"'") for t in re.split(r"\s+|(?<=[;&|()])|(?=[;&|()])", cmd) if t and t.strip()]

komendy, biez = [], []
for t in tokeny:
    if t in SEP:
        if biez:
            komendy.append(biez)
        biez = []
    else:
        biez.append(t)
if biez:
    komendy.append(biez)

def rozwin(x, b):
    """Real paths of x against b; a glob in it (`../../tmp/refak*/Plik/x`) expanded up to its last wildcard part, the
    rest appended, so a file that does not exist yet still resolves (r2 F12)."""
    out = [rp(x, b)]
    czesci = os.path.expanduser(x).split("/")
    gw = [i for i, c in enumerate(czesci) if re.search(r"[*?[]", c)]
    if gw:
        for m in glob.glob(os.path.join(b, "/".join(czesci[:gw[-1] + 1])))[:50]:
            out.append(os.path.realpath(os.path.join(m, *czesci[gw[-1] + 1:])))
    return out


def cel_cd(k):  # `cd -P x`, `cd -- x`: the first operand after the options (r2 F11)
    reszta = k[1:]
    while reszta and re.match(r"^(-[LPe@]+|--)$", reszta[0]):
        if reszta.pop(0) == "--":
            break
    return reszta[:1]


# Base directories: cwd and every cd/pushd/git -C target, each resolved against the bases known before it.
bazy, cele_git = [CWD], {}
for n_, k in enumerate(komendy):
    cele = []
    if k and os.path.basename(k[0]) in ("cd", "pushd"):
        cele += cel_cd(k)
    for i, t in enumerate(k[:-1]):
        if t == "-C" and k[0] == "git":
            cele.append(k[i + 1])
            cele_git.setdefault(n_, []).append(k[i + 1])
    for c in cele:
        bazy += [r for b in bazy for r in rozwin(c, b)]
bazy = list(dict.fromkeys(bazy))

kawalki = re.compile(r"[^\s=:'\"(),;`{}<>|&]+")


def sciezki(t):
    """The token and its path-like pieces (`of=x`, `--out=x`, `open('x','w')`, quoted code)."""
    out = {t} if t and not re.search(r"\s", t) else set()
    out |= {x for x in kawalki.findall(t) if "/" in x or x.startswith(".") or x.startswith("~")}
    return out


def trafia(t, przodki=False):
    for x in sciezki(t):
        for b in bazy:
            for r in rozwin(x, b):
                if w(r):
                    return True
                if przodki and przodek(r) and not w(CWD) and not (CWD == r or CWD.startswith(r.rstrip("/") + "/")):
                    return True
    return False


def skrypt_trafia(p):
    """A script file (python x.py, bash x.sh, ./x) whose text names the directory."""
    for b in bazy:
        f = rp(p, b)
        if os.path.isfile(f) and os.path.getsize(f) < 2_000_000:
            try:
                txt = open(f, encoding="utf-8", errors="replace").read()
            except OSError:
                continue
            if any(k in txt.casefold() for k in KORZ):
                return True
            for x in kawalki.findall(txt):
                if ("/" in x or x.startswith("~")) and any(w(rp(x, d)) for d in (b, os.path.dirname(f), *bazy)):
                    return True
    return False


def nazwa(k):
    i = 0
    while i < len(k) and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", k[i]) or k[i] in PREFIKSY):
        i += 1
    return (os.path.basename(k[i]) if i < len(k) else ""), i


def pisze(k):
    """Does the simple command write files by its own action (not a redirect)?"""
    n, i = nazwa(k)
    reszta = k[i + 1:]
    if n in PISZACE:
        return True
    if n in ("sed", "perl") and any(re.match(r"^(-[A-Za-z0-9]*i|--in-place)", t) for t in reszta):
        return True
    if n == "git" and any(t in ("checkout", "restore", "rm", "mv", "apply", "am", "clean", "reset", "stash", "switch")
                          for t in reszta):
        return True
    if n == "find" and any(t in ("-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf", "-fls")
                           for t in reszta):
        return True
    if n in ("xargs", "parallel"):
        j = 0
        while j < len(reszta) and reszta[j].startswith("-"):
            j += 2 if reszta[j] in ("-I", "-n", "-P", "-L", "-d", "-E", "-s") else 1
        return bool(reszta[j:]) and pisze(reszta[j:])
    return bool(INTERP.match(n)) or "/" in k[i]


cel_przekierowania = re.compile(r"^[0-9&]*(>|>>|>\||<>)$")
pisze_gdzies = False
for k in komendy:
    n, i = nazwa(k)
    for j, t in enumerate(k):
        if cel_przekierowania.match(t) and j + 1 < len(k) and trafia(k[j + 1]):
            wyjdz("BLOK\t" + k[j + 1])
        if re.match(r"^[0-9&]*>>?[^>&|]", t) and trafia(re.sub(r"^[0-9&]*>>?", "", t)):
            wyjdz("BLOK\t" + t)
    if not k[i:]:
        continue
    p = pisze(k)
    pisze_gdzies |= p or any(cel_przekierowania.match(t) for t in k)
    if p and any(trafia(t, przodki=(n in PRZODKOWE) or n == "ln") for t in k[i + 1:]):
        wyjdz("BLOK\t" + " ".join(k)[:160])
    if n == "ln" and any(trafia(t) or any(przodek(rp(x, b)) for x in sciezki(t) for b in bazy) for t in k[i + 1:]):
        wyjdz("BLOK\t" + " ".join(k)[:160])
    # A script: `python3 x.py`, `bash x.sh`, `./x` — its text naming the directory counts as the command naming it.
    kand = []
    if INTERP.match(n):
        kand = [t for t in k[i + 1:] if not t.startswith("-")][:1]
    elif "/" in k[i]:
        kand = [k[i]]
    if any(skrypt_trafia(x) for x in kand):
        wyjdz("BLOK\t" + " ".join(k)[:160] + " (skrypt zapisuje katalog nadzorcy)")
# $(…) and backticks (the path is in a substitution whose result a writer or a redirect uses), and an interpreter anywhere
# in the line (a heredoc body falls apart into tokens of its own): the path anywhere in the command is enough.
# `git clean` run in an ancestor of the directory (`git -C ../../.. clean -fdX`: it is ignored, so -X deletes it; r2 F16).
for n_, k in enumerate(komendy):
    if k and k[0] == "git" and "clean" in k:
        for c in cele_git.get(n_, []) or ["."]:
            if any(w(r) or przodek(r) for b in bazy for r in rozwin(c, b)):
                wyjdz("BLOK\t" + " ".join(k)[:160])
interp = any(INTERP.match(nazwa(k)[0]) for k in komendy if k[nazwa(k)[1]:])
# xargs/parallel running a writer: the path reaches it through the pipe, not as its argument (r2 F10).
xa = any(nazwa(k)[0] in ("xargs", "parallel") and pisze(k) for k in komendy if k[nazwa(k)[1]:])
if (("$(" in cmd or "`" in cmd) and pisze_gdzies or interp or xa) and any(trafia(t) for k in komendy for t in k):
    wyjdz("BLOK\t" + cmd[:160])
wyjdz("OK")
