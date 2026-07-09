{
  description = "Eval-time visible, build-checked contracts for Nix derivations";

  outputs = _: {
    lib.contractHook = import ./contractHook.nix;
    lib.withContract = import ./withContract.nix;
  };
}
