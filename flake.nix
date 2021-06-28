{
  description = "babariviere's blog";

  inputs = { utils.url = "github:numtide/flake-utils"; };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in with pkgs; { devShell = mkShell { buildInputs = [ hugo ]; }; });
}
