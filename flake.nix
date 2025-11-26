{
  description = "";

  inputs = {
    unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, unstable } : let
    systems = [ "x86_64-linux" "aarch64-linux"];
    lib = unstable.lib;
    forEachSystem = func: lib.foldAttrs (item: acc: item // acc) {} (lib.map func systems);
  in forEachSystem (system: let
      pkgs = unstable.legacyPackages.${system};
    in {
      packages.${system} = rec {
        default = rug;
        
        rug = pkgs.zigStdenv.mkDerivation {
          inherit system;
          name = "rug";
          src = ./.;
          buildInputs = [ pkgs.zig ];

          buildPhase = ''
            runHook preBuild

            zig build -Doptimize=ReleaseSafe --global-cache-dir $(pwd)/.global-cache -p $out

            runHook postBuild
          '';
        };
      };
      
      devShell.${system} = pkgs.mkShell {
        buildInputs = [ pkgs.zig pkgs.zls ];
        shellHook = ''
          echo "Entered Rug.NET development shell"
        '';
      };
    }
  );
}
