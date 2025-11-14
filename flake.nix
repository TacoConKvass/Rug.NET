{
    description = "A Rug compiler for the .NET platform";
    
    inputs = {
        stable.url = "github:NixOS/nixpkgs/nixos-25.05";
        unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    };

    outputs = { self, stable, unstable }: let
        systems = [ "x86_64-linux" "aarch64-linux" ];
        lib = stable.lib;
        pkg = lib.genAttrs systems (system: {
            stable = stable.legacyPackages.${system};
            unstable = unstable.legacyPackages.${system};
        });
    in {
        packages = lib.genAttrs systems (system: let
            pkgs = pkg.${system};
            zig = pkgs.unstable.zig;
        in {
            rug = pkgs.unstable.zigStdenv.mkDerivation {
                inherit system;
                name = "rug";
                src = ./.;
                buildInputs = [ zig ];

                buildPhase = ''
                    runHook preBuild

                    zig build -Doptimize=ReleaseSafe --global-cache-dir $(pwd)/.global-cache -p $out
                    
                    runHook postBuild
                '';
            };
        }); 
    };
}
