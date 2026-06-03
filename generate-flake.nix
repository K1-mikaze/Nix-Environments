let
  childSpecs = import ./child-specs.nix;
  mkInputLine = spec: "${spec.name} = { url = \"${spec.path}\"; inputs = { nixpkgs.follows = \"nixpkgs\"; flake-utils.follows = \"flake-utils\"; }; };";
  inputLines = builtins.concatStringsSep "\n    " (map mkInputLine childSpecs);
  template = builtins.readFile ./flake.nix.template;
in
builtins.replaceStrings [ "__INPUTS__" ] [ inputLines ] template
