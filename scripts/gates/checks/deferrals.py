"""A scope declaration is a stub.

The highest-yield gate in this harness. In the build that produced this rule,
three of the worst shipped defects were correctly described in a code comment
*by the agent that created them*, and shipped anyway. An agent noticing a gap
and writing it down is the system working; leaving it as prose is the system
failing.

So: prose that names a gap is a build failure until it is either fixed or
baselined with an owner and a reason.
"""

from __future__ import annotations

import re
from typing import Iterator

from run import Context, Finding

NAME = "deferrals"

# Two tiers, because a noisy gate is a gate somebody switches off.
#
# TIER A -- the phrase is an admission on its own. Always a finding.
TIER_A = [
    (r"\bout of scope\b", "scope declaration"),
    (r"\bthis (?:wave|pass|phase)\b[^.]{0,40}\b(?:only|just)\b", "scope declaration"),
    (r"\bbelongs to (?:the |whichever |another |a different )", "ownership deferral"),
    (r"\bnot (?:readable|writable|wired|hooked|connected|hooked up) (?:here|yet)\b", "known dead wiring"),
    (r"\b(?:later|another|a different|the other) (?:module|service|wave|resource|ticket|PR)\b", "ownership deferral"),
    # Case-SENSITIVE: these are conventions written in caps. Lowercased, "xxx"
    # matches the middle of any formatted-number example ("₦x,xxx.xx").
    (r"(?-i:\b(?:TODO|FIXME|HACK|XXX)\b)", "todo"),
    (r"\bfor now\b", "temporary implementation"),
    (r"\bcoming soon\b", "unbuilt feature"),
    (r"\bnot (?:yet )?implemented\b", "unbuilt feature"),
    (r"\bin (?:a|the) (?:future|follow-?up)\b", "deferral"),
    (r"\bwill be (?:added|implemented|wired|replaced|hooked)\b", "deferral"),
    (r"\bnobody (?:calls|reads|writes)\b", "known dead code"),
    (r"\bdead code\b", "known dead code"),
    (r"\b(?:is|are|gets?) never (?:called|invoked|triggered|reached|read)\b", "known dead code"),
]

# TIER B -- the phrase is ordinary English that is only an admission when it
# sits next to a deferral marker. Describing what IS real is not a deferral;
# promising something real LATER is. This split is what keeps the gate quiet
# enough to stay switched on.
TIER_B = [
    (r"\b(?:real|proper|actual) impl(?:ementation)?\b", "placeholder implementation"),
    (r"\b(?:mock|fake|stub|dummy|hardcod\w+|hard-cod\w+|placeholder)\b", "placeholder implementation"),
    (r"\b(?:wire|implement|replace|hook|swap)\b", "deferred wiring"),
]

# A comment recording something that ALREADY HAPPENED is not a deferral. It is
# the most valuable kind of comment in a repo — it tells the next reader what a
# line used to do and why it stopped — and this gate used to punish it, because
# an accurate note about a removed promise necessarily quotes the promise.
#
# Observed: an agent removed a false "we will email you" promise, wrote a comment
# explaining the removal, and the gate flagged its own explanation. It reworded
# the comment into vagueness to appease the check rather than saying the check
# was wrong. Both available moves — delete the history, or blur it — make the
# codebase worse, and the gate was steering toward them.
#
# So: a match is suppressed when the same line, or one immediately around it,
# carries evidence that the thing is DONE. Deliberately narrow. A bare "fixed"
# would let anyone wave a TODO through, so this wants a citation (a ruling or
# request id), an explicit past-tense removal, or a dated record.
RESOLUTION_MARKER = re.compile(
    r"\b(?:R-\d+|BR-\d+|C-\d+|S-\d+|X-\d+)\b"          # cites a recorded ruling
    r"|\b(?:removed|deleted|dropped|replaced|corrected|resolved)\b"
    r"\s+(?:on|in|by|per|—|-)"                            # ...attributed, not asserted
    r"|\b(?:used to|previously|formerly|no longer|until \d{4}-\d{2}-\d{2})\b"
    r"|\b\d{4}-\d{2}-\d{2}\b",                            # a date: this is a record
    re.IGNORECASE,
)

DEFERRAL_MARKER = re.compile(
    r"\b(?:later|until|once|eventually|when (?:we|the|it|this)|temporar\w+|pending|"
    r"before (?:ship|launch|prod|release)|in v\d|next (?:pass|wave|release|sprint)|"
    r"for now|not yet|someday|revisit)\b",
    re.IGNORECASE,
)

# Matched anywhere, comment or not. These are admissions the compiler accepts.
CODE_PATTERNS = [
    (r"\bUnimplementedError\b", "explicit unimplemented throw"),
    (r"\bthrow\s+(?:new\s+)?Error\(\s*['\"]not implemented", "explicit unimplemented throw"),
    # Skipped tests only. `.skip(` alone also matches Dart's Iterable.skip and
    # every other collection API, so the test runner's own names are required.
    (r"@Skip\(|\b(?:it|test|describe|group|context)\.skip\(|\bxit\(|\bxdescribe\(|\bit\.todo\(",
     "skipped test"),
]

COMMENT_PREFIXES = ("//", "///", "#", "*", "/*", "<!--")


def _is_comment(line: str) -> bool:
    stripped = line.strip()
    if stripped.startswith(COMMENT_PREFIXES):
        return True
    # trailing comment on a code line
    return "//" in line or "/*" in line


def _comment_part(line: str) -> str:
    for marker in ("///", "//", "/*", "#"):
        idx = line.find(marker)
        if idx != -1:
            return line[idx:]
    return line


def run(ctx: Context) -> Iterator[Finding]:
    tier_a = [(re.compile(p, re.IGNORECASE), label) for p, label in TIER_A]
    tier_b = [(re.compile(p, re.IGNORECASE), label) for p, label in TIER_B]
    code_res = [(re.compile(p, re.IGNORECASE), label) for p, label in CODE_PATTERNS]
    include_tests = ctx.gate_config.get("include_tests", False)

    for path in ctx.source_files("source"):
        if not include_tests and ctx.is_test(path):
            continue
        rel = ctx.rel(path)
        lines = [ln for _, ln in ctx.lines(path)]
        for idx, line in enumerate(lines):
            lineno = idx + 1
            if _is_comment(line):
                target = _comment_part(line)
                hit = next((lbl for rx, lbl in tier_a if rx.search(target)), None)
                if hit is None and DEFERRAL_MARKER.search(target):
                    hit = next((lbl for rx, lbl in tier_b if rx.search(target)), None)
                # A record of something already done is not a deferral. Look at
                # the neighbours too: an explanation usually runs several lines,
                # and the citation that resolves it often sits on a different
                # one from the phrase that matched.
                if hit and any(
                    RESOLUTION_MARKER.search(lines[i])
                    for i in range(max(0, idx - 3), min(len(lines), idx + 4))
                ):
                    hit = None
                if hit:
                    yield Finding(
                        gate=NAME,
                        path=rel,
                        line=lineno,
                        message=f"{hit} left as prose - resolve it or baseline it with a reason",
                        evidence=line,
                    )
            for rx, label in code_res:
                if rx.search(line):
                    yield Finding(
                        gate=NAME, path=rel, line=lineno, message=label, evidence=line
                    )
                    break
