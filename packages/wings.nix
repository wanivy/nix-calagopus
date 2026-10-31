{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "calagopus-wings";
  version = "1.2.7";

  src = fetchurl {
    url = "https://github.com/calagopus/wings/releases/download/release-${finalAttrs.version}/wings-rs-x86_64-linux";
    hash = "sha256-6stsOx7wa/fN489axLgoeNjjve9G29by5vjkD+SVdlw=";
  };

  dontUnpack = true;
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/calagopus-wings"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    "$out/bin/calagopus-wings" --version | grep -F "calagopus-wings ${finalAttrs.version}"
  '';

  meta = {
    description = "Server control plane for Calagopus Panel";
    homepage = "https://calagopus.com";
    license = lib.licenses.mit;
    mainProgram = "calagopus-wings";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
