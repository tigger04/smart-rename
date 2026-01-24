{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "smart-rename";
  version = "5.21.16";

  src = ./.;

  nativeBuildInputs = with pkgs; [
    makeWrapper
  ];

  buildInputs = with pkgs; [
    bash
    curl
    jq
    yq-go
    fd
    poppler_utils  # provides pdftotext
  ];

  # Optional runtime dependency
  propagatedBuildInputs = with pkgs; [
    ollama  # Optional for local AI processing
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Create directories
    mkdir -p $out/bin
    mkdir -p $out/share/smart-rename

    # Install main script
    install -m 755 smart-rename $out/bin/smart-rename

    # Install support library
    install -m 644 summarize-text-lib.sh $out/share/smart-rename/

    # Install example config
    install -m 644 config.yaml $out/share/smart-rename/

    # Wrap the script to ensure dependencies are in PATH
    wrapProgram $out/bin/smart-rename \
      --prefix PATH : ${pkgs.lib.makeBinPath buildInputs}

    runHook postInstall
  '';

  postInstall = ''
    # Verify the script is properly wrapped and executable
    $out/bin/smart-rename --version > /dev/null
  '';

  meta = with pkgs.lib; {
    description = "AI-powered file renaming tool that generates intelligent, descriptive filenames";
    longDescription = ''
      Smart-rename analyzes file content using AI (local Ollama by default, or OpenAI/Claude APIs)
      to generate intelligent filenames. Special formatting for receipts/invoices with
      YYYY-MM-DD-amount-description format. Supports batch processing with pattern matching.
    '';
    homepage = "https://github.com/tigger04/smart-rename";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.unix;
    mainProgram = "smart-rename";
  };
}