# Agent instructions

This repository manages the NixOS configuration for `iroh`. Read the relevant
modules and documentation before changing them. Preserve unrelated work in the
checkout.

## Module composition

- Follow the existing structure: ordinary NixOS modules, explicit `imports`, and
  upstream NixOS and Home Manager options used directly.
- Keep host composition in `hosts/<host>/default.nix`; keep reusable configuration
  in focused modules under `modules/`.
- Pass flake dependencies through the existing `inputs` and `self` arguments.
  Do not introduce a new module framework, automatic discovery, or a custom
  option namespace without an owner-requested architectural change.
- Format Nix with the flake's Alejandra formatter. Preserve attribution and
  license headers.

## Services

Choose implementations in this preference order:

1. Native NixOS service modules (`services.<name>` in a NixOS module).
2. OCI containers (`virtualisation.oci-containers`).
3. Custom systemd units (`systemd.services`).

Use the first suitable implementation. Document why a service needs a lower
priority implementation. Supporting systemd settings for a native service or
container do not change its classification.

Each service owns its configuration, secret declarations, encrypted SOPS file,
checks, and documentation. Keep these easy to find together; for new services,
prefer `modules/services/<name>/` with `default.nix`, `secrets.yaml` when needed,
`tests/`, and `README.md`. Do not create empty secret files for services that do
not need secrets.

### Service secrets

- Service secrets are not centralized. Set `sopsFile` explicitly on each
  service-owned secret so it does not inherit a shared default accidentally.
- Shared SOPS setup may configure decryption identities and tooling, but service
  secret declarations belong to their service modules.
- All non-dummy, non-test SOPS files use the same key groups, defined centrally
  in `.sops.yaml`. Service files remain separate; their recipient policy is
  shared. Preserve the groups and thresholds when moving or creating files.
  Add matching creation rules for new service file locations using those groups.
  Declare runtime ownership, permissions, and restart or reload behavior.
- Refer to decrypted runtime paths; never embed production plaintext or private
  decryption keys in Nix expressions, the Nix store, logs, or Git.
- The current `secrets/secrets.yaml` and shared `defaultSopsFile` are legacy
  configuration. Do not add new service secrets there. Migrate existing entries
  only as part of scoped work that preserves their consumers and recipients.

### Service checks

- Every service must have its own NixOS check using
  `pkgs.testers.runNixOSTest`, exposed through `checks.<system>.<name>`.
  This is the current documented entry point for tests outside Nixpkgs; use it
  rather than copying older `pkgs.nixosTest` or `testing-python.nix` examples.
- Each service also needs integration coverage for its actual behavior and
  dependencies. This can live in the same NixOS test when it exercises the full
  integration; separate derivations are useful when they isolate distinct cases.
- Import the actual service module into tests. Use minimal test nodes and avoid
  importing production hardware, disk layouts, or unrelated host services.
- Assert useful behavior, such as an authenticated request, a database operation,
  or communication between services. Checking only that a unit starts is not
  sufficient. Use bounded readiness waits instead of fixed sleeps.
- Services requiring secrets must use their own encrypted test SOPS files with
  dummy values. Exercise SOPS decryption and consumption by the service.
- Encrypt all test SOPS files to the same dedicated age public key. Keep the
  matching test private key publicly available in the repository so local tests
  and PR CI can decrypt fixtures without CI credentials. This keypair protects
  no confidential data: never use it for production recipients or real secrets.
- Make test identities available inside test machines before secret activation.
  Keep test and production identities and SOPS creation rules separate; ensure
  fixture rules take precedence over broader production path rules.

### OCI tests

The main sandbox constraint is image fetching: ordinary sandboxed test builds
have no external network access, so a container cannot pull its image from a
registry during the test. Running the container inside a VM does not remove
this constraint.

Supply images as declared Nix build inputs through `imageFile` or `imageStream`.
Fetch registry images through a fixed-output fetcher such as
`pkgs.dockerTools.pullImage`, with a pinned image digest, output hash, and explicit
architecture. Fixed-output fetchers can access the network; the subsequent test
loads the resulting image from the Nix store and runs offline. Reuse the deployed
image in tests, avoiding a substitute image that hides incompatibilities.

Run the OCI runtime inside the NixOS test VM, without a host Docker or Podman
socket or disabling sandboxing. Stub external dependencies locally. Document
runner requirements such as KVM and the tested architecture.

## Checks and GitHub CI

- Run checks in GitHub Actions. Expose checks through the flake so developers
  can run the same checks locally.
- Maintain an explicit mapping from changed repository paths to affected checks.
  Do not run every service check on every PR.
- Map service modules, test fixtures, encrypted secrets, packages, and relevant
  shared dependencies. A shared module change must select its consumers' checks.
- Compare the PR head against its merge base with the target branch. Handle
  additions, deletions, and both paths of renames.
- Changes to `flake.nix`, `flake.lock`, shared test infrastructure, or check
  selection logic must select all potentially affected checks. If the mapping
  cannot establish the affected set, fall back to the full suite.
- Documentation-only changes may skip runtime checks. Always report the selected
  checks and why they were selected, including when no runtime checks apply.
- Keep a stable required CI status that succeeds only when selection and all
  selected checks succeed. An empty selection is valid only when accounted for.
- `nix-community/nix-github-actions` can generate a matrix from flake checks;
  file-to-check selection must be implemented separately. Keep the mapping in
  one authoritative place rather than duplicating it across workflows.
- Adding a service includes adding its checks to the mapping and CI. Verify the
  selector with representative service, shared, renamed, and deleted paths.
- Run PR checks without production secrets. Use isolated runners for untrusted
  code, especially when the runner is self-hosted.

The current flake has no `checks` output or GitHub CI workflows. These rules
describe requirements for new work, not infrastructure that already exists.

For the existing configuration, useful local validation is:

```sh
nix flake check --no-build --no-update-lock-file
nix fmt -- --check flake.nix hosts modules packages
```

Evaluation alone does not execute integration tests. Once checks are defined,
build each selected check with `nix build .#checks.<system>.<name> -L`. Report
what actually ran and any validation that could not run.

## Documentation

Document every service and update its documentation alongside behavior changes.
Write primarily for LLMs while making the text pleasant for humans: use clear
headings, precise paths and option names, short explanations, and runnable
examples. Explain decisions and operational behavior rather than repeating Nix.

Each service's documentation should cover:

- Purpose, implementation choice, module path, and how hosts enable it.
- Dependencies, ports, network exposure, and authentication.
- Secret names, encrypted file locations, recipients, and runtime consumers.
- Persistent data paths, ownership, backup and restore procedure where relevant.
- Health checks, logs, common failures, and restart or reload procedure.
- Local check commands, test fixtures, and CI path mapping.
- Upgrade, migration, and rollback considerations, especially for stored data.

Keep `README.md` as the entry point and link to service documentation. Clearly
distinguish implemented behavior from plans. Never put secret values in examples.

## Development workflow

- Never commit or push directly to `main`. Use branches named
  `<type>/<description>`, such as `feat/forgejo`, `fix/secret-reload`,
  `docs/agent-guidelines`, or `chore/dependency-updates`. Deliver changes through
  a PR.
- Use Conventional Commits: `<type>(<optional-scope>): <description>`, for example
  `feat(forgejo): add native service` or `docs: clarify service checks`. Use the
  same convention for PR titles.
- Feature requests are tracked as GitHub issues. Agents pick up an issue when
  the owner asks; do not independently implement unrelated backlog items.
  Direct owner instructions authorize the requested work.
- Commit often, at coherent milestones. Include only files belonging to the
  task; do not commit another contributor's uncommitted work.
- Keep PRs focused. Describe the resulting behavior, link the relevant issue
  when present, and include validation results and operational implications.
- Preserve existing hardware identifiers and state versions unless the task
  specifically calls for changing them. Review data migrations and recovery
  steps before modifying persistent state.
- Building and testing are separate from deployment. Activate a configuration
  on a real host only when the owner requests it.

## Renovate

Run self-hosted Renovate in GitHub Actions, using `renovatebot/github-action` on
a schedule and with a manual trigger. "Self-hosted" refers to managing the bot
ourselves; it does not require a self-hosted runner or a service on `iroh`.
Update all tracked dependencies: flake inputs and lock files, OCI image versions
and digests, GitHub Actions, and other pinned tools. Add appropriate managers or
custom extraction rules when a dependency is not recognized automatically. New
dependency declarations must be discoverable by Renovate.

Updates follow the same PR and CI rules as other changes. Prefer reproducible
pins over floating versions; refresh related hashes with their pins. Keep bot
credentials outside the repository and unavailable to PR checks. Document
dependencies that cannot yet be updated automatically and how to address them.

## Operational invariants

- **State survives reboot.** For stateful services, classify writable paths as
  durable data, regenerable cache, or disposable runtime state. Account for the
  host's `/persist` layout and persistent `/var/lib` mount. Test writing data,
  rebooting the VM, and reading it again; a service restart alone does not test
  boot ordering or persistence.
- **Secret rotation reaches the process.** When changing secret consumption,
  test replacement with a second dummy credential through the configured
  activation and reload or restart path. Verify that the new credential works
  and the old one stops working where the service supports revocation. Boot-time
  decryption alone does not prove that a running service picks up rotations.
- **Exposure is intentional.** Specify which interfaces and clients may reach
  each service. For networking and authentication changes, use another test node
  to verify allowed access and rejected access, including direct backend access
  when a reverse proxy provides authentication.
- **Removal preserves recoverability.** Removing a module disables its service;
  it must not silently delete persistent data. Document retained paths, secret
  consumers, ports, and backup jobs that need cleanup. Data deletion is separate,
  explicitly requested work.
- **Nix rollback and data rollback are distinct.** For upgrades that migrate a
  database or file format, state whether the previous package can read the new
  state. Document a tested recovery path when rolling back the NixOS generation
  alone is insufficient.

## Ideas for future tooling

These are proposals, not infrastructure that already exists or requirements to
implement during unrelated tasks:

- **Audit selective CI against Nix itself.** Periodically compare check derivation
  paths at a PR's merge base and head, and flag changed or newly added checks
  omitted by the file mapping. A removed check should have an explicit reason.
  This catches dependency edges that humans forgot to list. Avoid accidentally
  including the entire repository as an input to every check, which would make
  this audit and selective CI ineffective.
- **Show the effective host change.** Attach a concise before/after inventory of
  enabled services, listening addresses, firewall ports, persistent paths, and
  secret consumers to configuration PRs. Reviewing the resulting configuration
  can expose interactions that are hard to see in a small Nix diff.
- **Check SOPS policy without decryption.** Validate that every production file's
  recipient groups and threshold match `.sops.yaml`, and that every test fixture
  uses only the shared test recipient. This checks ownership policy without
  handing production keys to CI.

## References

- [NixOS test framework](https://nixos.org/manual/nixos/stable/#sec-call-nixos-test-outside-nixos)
- [Upstream OCI test examples](https://github.com/NixOS/nixpkgs/blob/master/nixos/tests/oci-containers.nix)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [nix-github-actions](https://github.com/nix-community/nix-github-actions)
- [Self-hosted Renovate in GitHub Actions](https://github.com/renovatebot/github-action)
