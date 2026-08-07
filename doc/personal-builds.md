# Personal branch and nightly builds

This fork keeps upstream changes, contributable features, and personal tooling separate.

## Branches

- `main` is force-mirrored from `microsoft/terminal:main`; it must not contain fork-only commits.
- `fix-erase-scrollback-offset` contains the scrollback fix and its TerminalCore unit test.
- `fix-cascadia-package-platform-mapping` contains the CascadiaPackage solution-platform fix.
- `personal` merges all wanted feature branches and adds personal-only tooling and packaging changes.

Feature branches remain based on upstream history so they can be rebased and proposed upstream independently. New personal builds should merge feature branches rather than copy their changes into personal-only commits.

The scheduled workflow merges new upstream `main` commits into `personal`. It does not rewrite feature branches. A merge conflict intentionally fails the workflow and must be resolved on `personal`.

Because GitHub only runs scheduled workflows from a repository's default branch, this fork uses `personal` as its default branch while retaining `main` as the exact upstream mirror.

## Local update

From the repository root, run:

```powershell
pwsh .\tools\Update-TerminalDev.ps1
```

This pulls `me/personal`, performs a `Release|x64` rebuild with limited concurrency, and deploys the loose package. Launch it with `wtd`.

## Nightly releases

`.github/workflows/personal-nightly.yml` runs daily and can also be dispatched manually. It:

1. Force-mirrors upstream `main` to the fork's `main`.
2. Merges upstream `main` into `personal`.
3. Builds the x64 Release package and TerminalCore unit tests.
4. Creates and signs a versioned `.msixbundle`.
5. Publishes an immutable, versioned GitHub prerelease.

The package has the stable identity `Wilt.WindowsTerminalPersonal` and publisher `CN=wilt00`. Builds use a persistent self-signed certificate held in the repository's encrypted Actions secrets. Do not replace that certificate casually: retaining it means each machine only needs to trust the certificate once and allows later versions to upgrade the existing package.

For a first install, download all release assets into one directory and run with Windows PowerShell:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Install-TerminalNightly.ps1
```

The installer trusts the public certificate for the current user, installs the XAML dependency if present, and installs or updates the bundle.

## Future WinGet repository

The releases intentionally provide what a custom WinGet manifest will need:

- a stable package identity and publisher;
- monotonically increasing four-part package versions;
- versioned tags and asset URLs;
- an x64 `.msixbundle` asset;
- a stable signing certificate;
- immutable historical releases for version-specific installer URLs and SHA-256 hashes.

The certificate must be trusted once before WinGet can install these self-signed packages. A future repository bootstrap should install `WindowsTerminalPersonal.cer` into the current user's `TrustedPeople` store before adding the custom source.
