{
  version ? "dirty",
  extraPackages ? [ ],
  runtimeDeps ? [
    bash
    brightnessctl
    cliphist
    ddcutil
    wlsunset
    wl-clipboard
    wlr-randr
    imagemagick
    wget
    (python3.withPackages (
      pp:
      (lib.optional calendarSupport pp.pygobject3)
      ++ [
        pp.icalendar
        pp.recurring-ical-events
      ]
    ))
  ],

  lib,
  stdenvNoCC,
  # build
  qt6,
  makeWrapper,
  quickshell,
  # runtime deps
  bash,
  brightnessctl,
  cliphist,
  ddcutil,
  wlsunset,
  wl-clipboard,
  wlr-randr,
  imagemagick,
  wget,
  python3,
  wayland-scanner,
  # calendar support
  calendarSupport ? false,
  evolution-data-server,
  libical,
  glib,
  libsoup_3,
  json-glib,
  gobject-introspection,
}:
let
  src = lib.cleanSourceWith {
    src = ../.;
    filter =
      path: type:
      !(builtins.any (prefix: lib.path.hasPrefix (../. + prefix) (/. + path)) [
        /.direnv
        /.github
        /.gitignore
        /Assets/Screenshots
        /Scripts/dev
        /examples
        /plans
        /nix
        /LICENSE
        /README.md
        /flake.nix
        /flake.lock
        /shell.nix
        /lefthook.yml
        /CLAUDE.md
        /CREDITS.md
      ]);
  };

  giTypelibPath = lib.makeSearchPath "lib/girepository-1.0" [
    evolution-data-server
    libical
    glib.out
    libsoup_3
    json-glib
    gobject-introspection
  ];
in
stdenvNoCC.mkDerivation {
  pname = "quicknix-shell";
  inherit version src;

  nativeBuildInputs = [
    makeWrapper
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtmultimedia
  ];

  installPhase = ''
    mkdir -p $out/share/quicknix-shell $out/bin
    cp -r . $out/share/quicknix-shell
    makeWrapper ${quickshell}/bin/qs $out/bin/quicknix-shell \
      --prefix PATH : ${lib.makeBinPath (runtimeDeps ++ extraPackages)} \
      --prefix XDG_DATA_DIRS : ${wayland-scanner}/share \
      --set-default QS_CONFIG_PATH "$out/share/quicknix-shell" \
      ${lib.optionalString calendarSupport "--prefix GI_TYPELIB_PATH : ${giTypelibPath}"}
  '';

  meta = {
    description = "A sleek and minimal desktop shell thoughtfully crafted for Wayland, built with Quickshell.";
    homepage = "https://github.com/quicknix-dev/quicknix-shell";
    license = lib.licenses.mit;
    mainProgram = "quicknix-shell";
  };
}
