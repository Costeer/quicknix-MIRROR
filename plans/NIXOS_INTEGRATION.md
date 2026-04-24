Objective: Create a Quickshell configuration repo designed to be deployed by NixOS at a fixed config path and controlled via environment variables.
1. Context and constraints
   - Configuration will be deployed by NixOS into /etc/xdg/quickshell (or a configured path).
   - No Home‑Manager. No local user config assumptions.
   - NixOS will pass env vars for host/profile/theme and may pass CLI args.
   - Repo is hosted on SourceHut and pulled as a flake input.
2. Repo layout
   - Choose a simple root:
     - config/ as the main config directory, or the repo root itself.
   - If possible, include:
     - hosts/ for host‑specific overrides (hosts/laptop, hosts/desktop)
     - profiles/ for feature sets or modes
     - themes/ for theme files
3. Environment contract
   - Decide on env variables that the NixOS module will set:
     - QS_CONFIG_DIR → points to deployed config root.
     - QS_HOST → selects host overrides.
     - QS_PROFILE → selects profile or mode.
     - QS_THEME → selects a theme.
   - Implement config loading logic to:
     - Load base config from $QS_CONFIG_DIR.
     - Overlay hosts/$QS_HOST if set and exists.
     - Overlay profiles/$QS_PROFILE if set and exists.
     - Apply theme from themes/$QS_THEME.
4. CLI arg support
   - If Quickshell supports CLI args (like --config), document them in repo README.
   - Ensure config can load via the --config path the systemd unit will pass.
5. Secrets and sensitive data
   - Do not store secrets in repo.
   - If needed, expect runtime env vars or a separate /etc/quickshell/secret file managed by NixOS.
6. Compatibility metadata
   - Add metadata.json or version.txt indicating:
     - expected env keys
     - supported profiles/themes
     - minimal Quickshell version
   - This helps NixOS defaults and validation.
7. Local testing
   - Provide a minimal script or instructions:
     - Run Quickshell with QS_CONFIG_DIR=... QS_HOST=... quickshell --config ...
   - Ensure config doesn’t assume Home‑Manager file locations.
8. Coordination contract
   - Publish a small “integration contract” section in README:
     - expected env vars
     - expected config layout
     - default values if env vars not set
