# Lens examples (illustrative, non-exhaustive)

These are examples of what a "10,000-foot" lens can look like once Phase 3's discovery step
has looked at a specific repo — **not** a checklist to run through. The whole point of Phase
3 is that the lens set is discovered fresh from what the target repo actually contains; a
lens below that doesn't fit the repo at hand should be dropped, and a repo can just as easily
surface a lens none of these examples cover. Treat this file as inspiration for the *kind* of
question worth asking, never as a fixed enumeration.

## A docs-heavy repo → docs-site UX as an independent second opinion

A repo with a real docs site (this marketplace's own `dev-kit:generate-docs` output is one
example) can get a lens that judges the site as a *reader* would, independent of whatever
`generate-docs` already concluded about its own drift-and-omission reconciliation: does the
landing page orient a first-time visitor, does the information architecture match how someone
actually looks for things, is there prose that reads as generated boilerplate rather than
authored explanation, does one page duplicate another's content instead of linking to it. This
is deliberately **not** re-running `generate-docs`'s own self-assessment — it's a fresh,
holistic read of the same artifact from a different angle.

## A CLI-shaped repo → flag/config surface internal consistency

A repo that ships a command-line tool or a set of subcommands can get a lens on whether its
flags, config keys, and subcommand names are internally consistent: does `--dry-run` mean the
same thing in every subcommand that has it, is one flag `--verbose` and another `--verbosity`
for no reason, do config file keys use the same casing convention throughout, does every
subcommand's `--help` text follow the same voice and structure. This lens has nothing to do
with docs-site UX and wouldn't occur to a discovery step looking at a repo with no CLI at
all — it's specific to what this kind of repo actually exposes to a user.

## A test-heavy repo → whole-suite DRYness and structure

A repo with a large test suite can get a lens judging the suite holistically, across every
unit at once — not the same thing as Phase 2's per-unit test judgment, which stays scoped to
one unit's own colocated tests in isolation. A whole-suite lens can ask: is the same fixture
or setup boilerplate copy-pasted across many test files instead of factored into a shared
helper, does the suite's directory structure mirror the source it tests in a way a new
contributor could navigate, are there whole categories of behavior (error paths, edge cases)
that no unit's tests cover even though each individual unit's own tests look complete in
isolation.

## Where no lens applies at all

A repo with no docs site gets **no docs-UX lens** — not a lens that reports "no docs site
found" as a finding, simply the absence of that lens from this run's discovery output. The
same holds for any lens whose precondition the repo doesn't meet: a repo with no test suite at
all doesn't get a whole-suite-DRYness lens either (though the *absence* of any tests is itself
a legitimate finding — see the skill's Error handling section). This is the discovered-not-
enumerated principle made concrete: an empty discovery result for a given dimension is a
correct, expected outcome of judging *this* repo, not a gap in the discovery step's coverage.
