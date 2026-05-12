{
  description = "smc - Sequential Monte Carlo simulator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        emacs = pkgs.emacs-nox;

        emacsWithPackages = (pkgs.emacsPackagesFor emacs).emacsWithPackages
          (epkgs: [
            epkgs.package-lint
            epkgs.buttercup
          ]);

        sourceFiles = [
          "smc.el"
        ];

        sourceFilesString = pkgs.lib.concatStringsSep " " sourceFiles;

        copySrc = ''
          cp $src/*.el .
          chmod +w *.el

          if [ -f $src/smc.texi ]; then
            cp $src/smc.texi .
            chmod +w smc.texi
          fi

          if [ -d $src/tests ]; then
            mkdir -p tests
            cp $src/tests/*.el tests/
            chmod +w tests/*.el
          fi
        '';
        texliveForTexinfoPdf = pkgs.texlive.combine {
          inherit (pkgs.texlive) scheme-small texinfo;
        };
      in
      {
        checks = {
          compile = pkgs.runCommand "smc-compile" {
            nativeBuildInputs = [ emacs ];
            src = self;
          } ''
            ${copySrc}

            HOME=$TMPDIR emacs -Q --batch -L . \
              --eval '(setq byte-compile-error-on-warn t)' \
              -f batch-byte-compile \
              ${sourceFilesString}

            echo "==> byte-compile succeeded"

            touch $out
          '';

          package-lint = pkgs.runCommand "smc-package-lint" {
            nativeBuildInputs = [ emacsWithPackages ];
            src = self;
          } ''
            ${copySrc}

            HOME=$TMPDIR emacs -Q --batch -L . \
              -l package-lint \
              --eval '(package-lint-batch-and-exit)' \
              ${sourceFilesString}

            echo "==> package-lint succeeded"
            touch $out
          '';

          manual = pkgs.runCommand "smc-manual" {
            nativeBuildInputs = [ pkgs.texinfo ];
            src = self;
          } ''
            ${copySrc}

            makeinfo --verbose smc.texi -o smc.info
            test -s smc.info

            echo "==> manual build succeeded"
            touch $out
          '';

          pdf = pkgs.runCommand "smc-pdf" {
            nativeBuildInputs = [
              pkgs.texinfo
              texliveForTexinfoPdf
            ];
            src = self;
          } ''
            ${copySrc}

            texi2pdf smc.texi

            mkdir -p $out
            cp smc.pdf $out/

            echo "==> PDF manual succeeded"
          '';



          tests = pkgs.runCommand "smc-tests" {
            nativeBuildInputs = [ emacsWithPackages ];
            src = self;
          } ''
            ${copySrc}

            if [ -d tests ]; then
              HOME=$TMPDIR emacs -Q --batch -L . -L tests \
                -l buttercup \
                -f buttercup-run-discover
            fi

            echo "==> smc-tests succeeded"

            touch $out
          '';
        };

        devShells.default = pkgs.mkShell {
          packages = [
            emacsWithPackages
            pkgs.texinfo
          ];
        };
      });
}
