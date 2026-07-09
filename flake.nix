{
  description = "Eval-time visible, build-checked contracts for Nix derivations";

  outputs = _: {
    lib.withContract = import ./withContract.nix;
  };
}
