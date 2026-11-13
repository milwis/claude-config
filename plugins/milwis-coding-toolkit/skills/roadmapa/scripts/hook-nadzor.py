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
Fail-closed: a redirect target, an argument of a known writer or a cd/pushd target the hook cannot expand in full
(`$(…)`, backticks, `$VAR`, `~+`/`~-`, `<(…)`, zsh `=(…)` and glob qualifiers, braces or globs past the limits) is
refused. Interpreters are not: what a script writes the hook never sees — the known hole.
THE HOOK IS A GUARD AGAINST ACCIDENTS, NOT A SECURITY BOUNDARY. The hard boundary is a sandbox of the executor's session
with permissions.deny on the directory (claude-config #66), required before the first autonomous refactor.
"""
import fnmatch, functools, json, os, re, subprocess, sys, threading, time

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
    sys.stdout.flush()
    os._exit(0)   # a disk walk left in a thread (stuck in a slow directory) must not hold the exit


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
def skanuj(c):
    """Shell words by simple command, quoting removed, with a flag per word: True when the word holds something the hook
    does not model — `$(…)`, backticks, `$VAR` (assigned ones, $HOME and $PWD are already expanded), `${…}`, `~+`/`~-`,
    `<(…)`/`>(…)`/`=(…)`, a `(` inside a word (zsh glob qualifier, extglob). Single-quoted text is never expanded.
    Redirect operators are words of their own; a heredoc body is one word appended to its command; the text inside a
    substitution is appended too (flagged), so a path written there still counts as named."""
    cmds, words, flags = [], [], []
    st = {"w": [], "d": False, "in": False}
    heredocs, czeka = [], None
    i, n = 0, len(c)

    def koniec_slowa():
        nonlocal czeka
        if st["in"]:
            slowo = "".join(st["w"])
            words.append(slowo); flags.append(st["d"])
            if czeka:
                heredocs.append((slowo, czeka == "<<-")); czeka = None
        st["w"], st["d"], st["in"] = [], False, False

    def koniec_cmd():
        koniec_slowa()
        if words:
            cmds.append((list(words), list(flags)))
        words.clear(); flags.clear()

    def podstawienie(j, otw, zam):  # j after the opening; returns the index after the matching close
        d, start = 1, j
        while j < n and d:
            ch = c[j]
            if ch == "\\":
                j += 2; continue
            if ch == "'":
                k = c.find("'", j + 1); j = n if k < 0 else k + 1; continue
            if ch == otw:
                d += 1
            elif ch == zam:
                d -= 1
            j += 1
        words.append(c[start:j - 1]); flags.append(True)   # the inner text, as an extra (unmodelled) word
        st["d"] = st["in"] = True
        return j

    def dolar(j):  # c[j] == "$": an expansion? returns the new index or None
        nx = c[j + 1:j + 2]
        if nx == "(":
            return podstawienie(j + 2, "(", ")")
        if nx == "{":
            return podstawienie(j + 2, "{", "}")
        if nx and (nx.isalnum() or nx in "_?$!@*#-"):
            st["d"] = st["in"] = True
            st["w"].append("$" + nx)
            return j + 2
        return None

    while i < n:
        ch = c[i]
        if ch == "\\":
            if c[i + 1:i + 2] != "\n":
                st["w"].append(c[i + 1:i + 2]); st["in"] = True
            i += 2; continue
        if ch == "'":
            k = c.find("'", i + 1); k = n if k < 0 else k
            st["w"].append(c[i + 1:k]); st["in"] = True; i = k + 1; continue
        if ch == '"':
            j = i + 1; st["in"] = True
            while j < n and c[j] != '"':
                if c[j] == "\\" and j + 1 < n:
                    st["w"].append(c[j + 1]); j += 2; continue
                if c[j] == "`":
                    j = podstawienie(j + 1, "\x00", "`"); continue
                if c[j] == "$":
                    r = dolar(j)
                    if r is not None:
                        j = r; continue
                st["w"].append(c[j]); j += 1
            i = j + 1; continue
        if ch == "`":
            i = podstawienie(i + 1, "\x00", "`"); continue
        if ch == "$":
            r = dolar(i)
            if r is not None:
                i = r; continue
        if ch == "~" and not st["in"] and c[i + 1:i + 2] in ("+", "-"):
            st["d"] = True
        if ch in "<>=" and c[i + 1:i + 2] == "(":   # <(…) >(…) and zsh =(…); `a=(…)` ends up the same: unmodelled
            i = podstawienie(i + 2, "(", ")"); continue
        if ch in " \t":
            koniec_slowa(); i += 1; continue
        if ch == "\n":
            koniec_slowa(); i += 1
            for delim, strip in heredocs:
                body = []
                while i < n:
                    e = c.find("\n", i); e = n if e < 0 else e
                    line = c[i:e]; i = e + 1
                    if (line.lstrip("\t") if strip else line) == delim:
                        break
                    body.append(line)
                words.append("\n".join(body)); flags.append(False)
            heredocs = []
            koniec_cmd(); continue
        if ch == "#" and not st["in"]:
            e = c.find("\n", i); i = n if e < 0 else e; continue
        if ch == "&" and c[i + 1:i + 2] == ">":
            koniec_slowa()
            op = "&>>" if c[i + 2:i + 3] == ">" else "&>"
            words.append(op); flags.append(False); i += len(op); continue
        if ch in "<>":
            if st["in"] and "".join(st["w"]).isdigit() and not st["d"]:
                st["w"], st["in"] = [], False          # an fd number: 2>
            koniec_slowa()
            m = re.match(r"<<<|<<-|<<|>>|>\||>&|<&|<>|>|<", c[i:])
            op = m.group(0)
            words.append(op); flags.append(False); i += len(op)
            if op in ("<<", "<<-"):
                czeka = op
            continue
        if ch == "(" and st["in"]:
            i = podstawienie(i + 1, "(", ")"); continue   # zsh glob qualifier / extglob / array
        if ch in ";&|()":
            koniec_cmd()
            i += 2 if c[i:i + 2] in ("&&", "||", ";;", "|&") else 1
            continue
        st["w"].append(ch); st["in"] = True; i += 1
    koniec_cmd()
    return cmds


skan = skanuj(cmd)
komendy = [k for k, _ in skan]
FLAGI = [f for _, f in skan]

def nazwa(k):  # the command's name and index, past `X=1`, env, command, builtin, sudo, … (F20 of #58)
    i = 0
    while i < len(k) and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", k[i]) or k[i] in PREFIKSY):
        i += 1
    return (os.path.basename(k[i]) if i < len(k) else ""), i


LIMIT = 50


def grupa(y):
    """The first brace group bash/zsh would expand: (start, end, alternatives), alternatives None when over the limit."""
    for m in re.finditer(r"\{([^{}]*)\}", y):
        t = m.group(1)
        if "," in t:
            return m.start(), m.end(), t.split(",")
        r = re.fullmatch(r"(-?\d+)\.\.(-?\d+)(?:\.\.(-?\d+))?", t)
        if r:
            a, b = int(r.group(1)), int(r.group(2))
            krok = abs(int(r.group(3) or 1)) or 1
            if abs(b - a) // krok + 1 > LIMIT:
                return m.start(), m.end(), None
            szer = max(len(r.group(1)), len(r.group(2))) if re.match(r"-?0\d", r.group(1) + " ") or re.match(r"-?0\d", r.group(2) + " ") else 0
            return m.start(), m.end(), [str(v).zfill(szer) for v in range(a, b + (1 if b >= a else -1), krok if b >= a else -krok)]
        r = re.fullmatch(r"([A-Za-z])\.\.([A-Za-z])(?:\.\.(-?\d+))?", t)
        if r:
            a, b = ord(r.group(1)), ord(r.group(2))
            krok = abs(int(r.group(3) or 1)) or 1
            return m.start(), m.end(), [chr(v) for v in range(a, b + (1 if b >= a else -1), krok if b >= a else -krok)]
    return None


def klamry(x):
    """Brace expansion as bash/zsh do it — `{tmp,q}` (F19), `{l..n}`, `{1..9}` (F24 of #58): (alternatives, complete).
    Over 50 alternatives or 9 rounds the expansion is incomplete and a writer's argument counts as unmodelled (F26)."""
    wyn = [x]
    for _ in range(9):
        nowe, zmiana = [], False
        for y in wyn:
            g = grupa(y)
            if g is None:
                nowe.append(y); continue
            if g[2] is None:
                return wyn[:LIMIT], False
            zmiana = True
            nowe += [y[:g[0]] + alt + y[g[1]:] for alt in g[2]]
        if len(nowe) > LIMIT:
            return nowe[:LIMIT], False
        wyn = nowe
        if not zmiana:
            return wyn, True
    return wyn, not any(grupa(y) for y in wyn)


# One disk budget per hook call: every wildcard walk together reads at most 20000 entries in 0.5 s (F23 of #58).
BUDZET = {"wpisy": 20000, "koniec": time.monotonic() + 0.5}


def dysk(baza, czesci):
    """Paths matching the wildcard parts below baza, within the budget: (paths, complete). The walk runs in a thread
    joined until the budget's deadline: one scandir of a slow directory (network, cloud storage) can block for seconds."""
    wynik = []
    t = threading.Thread(target=lambda: wynik.append(_dysk(baza, czesci)), daemon=True)
    t.start()
    t.join(max(0.0, BUDZET["koniec"] - time.monotonic()))
    return wynik[0] if wynik else ([], False)


def _dysk(baza, czesci):
    biez = [baza]
    for comp in czesci:
        nast = []
        for d in biez:
            if not re.search(r"[*?[]", comp):
                nast.append(os.path.join(d, comp))
                continue
            stos = [d]
            while stos:
                kat = stos.pop()
                if comp == "**":
                    nast.append(kat)
                try:
                    it = os.scandir(kat)
                except OSError:
                    continue
                with it:
                    for e in it:
                        BUDZET["wpisy"] -= 1
                        if BUDZET["wpisy"] < 0 or time.monotonic() > BUDZET["koniec"]:
                            return nast, False
                        if comp == "**":
                            if e.is_dir() and not e.name.startswith("."):
                                stos.append(e.path)
                        elif fnmatch.fnmatchcase(e.name.casefold(), comp.casefold()) \
                                and (not e.name.startswith(".") or comp.startswith(".")):
                            nast.append(e.path)
        biez = nast
    return biez, True


@functools.lru_cache(maxsize=None)
def wzorzec(y, b):
    """A glob against the roots: (paths, complete). Part by part, case-folded, without the disk (r2 F12; F23); `[^` is
    the shell's negation, rewritten to fnmatch's `[!` (F25). Then the disk, bounded: a symlink in a wildcard part
    (`l?k/…` with lnk → ../../tmp) resolves only there (F27); past the disk budget the result is incomplete."""
    y = y.replace("[^", "[!")
    czesci = os.path.join(b, os.path.expanduser(y)).split("/")
    g = next((i for i, c in enumerate(czesci) if re.search(r"[*?[]", c)), None)
    if g is None:
        return (), True
    out, pelne = [], True
    if ".." not in czesci[g:]:
        wz = [c.casefold() for c in os.path.realpath("/".join(czesci[:g]) or "/").split("/") + czesci[g:] if c not in ("", ".")]
        for k in korzenie:
            kc = [c for c in k.split("/") if c]
            n = min(len(wz), len(kc))
            for i in range(n):
                if wz[i] == "**":
                    out.append(k)
                    break
                if not fnmatch.fnmatchcase(kc[i].casefold(), wz[i]):
                    break
            else:
                out.append("/" + "/".join(kc + wz[n:]) if len(wz) >= len(kc) else "/" + "/".join(kc[:n]))
    ost = max(i for i, c in enumerate(czesci) if re.search(r"[*?[]", c))
    trafione, pelne = dysk("/".join(czesci[:g]) or "/", czesci[g:ost + 1])
    out += [os.path.realpath(os.path.join(m, *czesci[ost + 1:])) for m in trafione]
    return tuple(out), pelne


@functools.lru_cache(maxsize=None)
def rozwin(x, b):
    """Real paths of x against b — braces expanded, globs matched — and whether that is all of them."""
    alt, pelne = klamry(x)
    out = []
    for y in alt:
        out.append(rp(y, b))
        r, p = wzorzec(y, b)
        out += r
        pelne &= p
    return tuple(out), pelne


def cel_cd(k):  # `cd -P x`, `cd -- x`, zsh `cd -q|-s x`: the first operand after the options (r2 F11, F20 of #58)
    reszta = k[1:]
    while reszta and re.match(r"^(-[LPeqsn@]+|--)$", reszta[0]):
        if reszta.pop(0) == "--":
            break
    return reszta[:1]


# Base directories: cwd and every cd/pushd/git -C target, each resolved against the bases known before it.
bazy, cele_git = [CWD], {}
for n_, k0 in enumerate(komendy):
    cele = []
    k = k0[nazwa(k0)[1]:]
    if k and os.path.basename(k[0]) in ("cd", "pushd"):
        cele += cel_cd(k)
    for i, t in enumerate(k[:-1]):
        if t == "-C" and os.path.basename(k[0]) == "git":
            cele.append(k[i + 1])
            cele_git.setdefault(n_, []).append(k[i + 1])
    for c in cele:
        bazy += [r for b in bazy for r in rozwin(c, b)[0]]
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
            for r in rozwin(x, b)[0]:
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


# Fail-closed (#58, after F24–F28): a path the hook cannot model in full — an unmodelled word (see skanuj), braces or a
# glob it could not expand completely — is refused where it is written: a redirect target, an argument of a known
# writer, a cd/pushd target followed by a write to a relative path. Interpreters are not in this list: what a script
# writes the hook never sees (the known hole, claude-config #66).
NIE_FC = {"curl", "wget", "tar", "unzip", "cpio", "ed", "ex", "vi", "vim"}


def niemodelowany(t, f):
    return f or any(not rozwin(x, b)[1] for x in sciezki(t) for b in bazy)


def fail_closed(k):  # a known writer whose arguments are paths
    n, i = nazwa(k)
    return pisze(k) and not INTERP.match(n) and "/" not in k[i] and n not in NIE_FC


cel_przekierowania = re.compile(r"^[0-9]*(>|>>|>\||<>|&>|&>>)$")
pisze_gdzies = cd_dyn = False
for k, fl in zip(komendy, FLAGI):
    n, i = nazwa(k)
    for j, t in enumerate(k):
        cel = j + 1 < len(k) and (cel_przekierowania.match(t) or t == ">&" and not k[j + 1].isdigit() and k[j + 1] != "-")
        if cel and trafia(k[j + 1]):
            wyjdz("BLOK\t" + k[j + 1])
        if cel and niemodelowany(k[j + 1], fl[j + 1]):
            wyjdz("BLOK\t" + k[j + 1] + " (cel przekierowania, którego hook nie rozwija w całości)")
        if cel and cd_dyn and not re.match(r"^(/|~)", k[j + 1]):
            wyjdz("BLOK\t" + " ".join(k)[:160] + " (zapis względny po cd do katalogu, którego hook nie rozwija)")
    if not k[i:]:
        continue
    if n in ("cd", "pushd") and any(niemodelowany(t, f) for t, f in zip(k[i:], fl[i:]) if t in cel_cd(k[i:])):
        cd_dyn = True
    if fail_closed(k):
        argi = [(t, f) for t, f in zip(k[i + 1:], fl[i + 1:]) if not cel_przekierowania.match(t)]
        if any(niemodelowany(t, f) for t, f in argi):
            wyjdz("BLOK\t" + " ".join(k)[:160] + " (argument polecenia piszącego, którego hook nie rozwija w całości)")
        if cd_dyn and any(not re.match(r"^(-|/|~)", t) for t, _ in argi):
            wyjdz("BLOK\t" + " ".join(k)[:160] + " (zapis względny po cd do katalogu, którego hook nie rozwija)")
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
    if nazwa(k)[0] == "git" and "clean" in k:
        for c in cele_git.get(n_, []) or ["."]:
            if any(w(r) or przodek(r) for b in bazy for r in rozwin(c, b)[0]):
                wyjdz("BLOK\t" + " ".join(k)[:160])
interp = any(INTERP.match(nazwa(k)[0]) for k in komendy if k[nazwa(k)[1]:])
# xargs/parallel running a writer: the path reaches it through the pipe, not as its argument (r2 F10).
xa = any(nazwa(k)[0] in ("xargs", "parallel") and pisze(k) for k in komendy if k[nazwa(k)[1]:])
if (("$(" in cmd or "`" in cmd) and pisze_gdzies or interp or xa) and any(trafia(t) for k in komendy for t in k):
    wyjdz("BLOK\t" + cmd[:160])
wyjdz("OK")
