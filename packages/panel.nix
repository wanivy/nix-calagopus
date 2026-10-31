{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "calagopus-panel";
  version = "1.2.7";

  src = fetchurl {
    url = "https://github.com/calagopus/panel/releases/download/release-${finalAttrs.version}/panel-rs-x86_64-linux";
    hash = "sha256-AYntoi2s4rv3USS1JHvfTJAYeWoQrEuUx3Vcqr6+1fc=";
  };

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/calagopus-panel"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    APP_ENCRYPTION_KEY=0123456789abcdef \
      "$out/bin/calagopus-panel" --version | grep -F "calagopus-panel ${finalAttrs.version}"
  '';

  meta = {
    description = "Game server management panel";
    homepage = "https://calagopus.com";
    license = lib.licenses.mit;
    mainProgram = "calagopus-panel";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
