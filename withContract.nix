{ pkgs, lib, ... }:

rawContract: drv:

let
  contract = rawContract;
  outputs = drv.outputs or [ "out" ];
  contractOutputNames = if builtins.isAttrs contract then builtins.attrNames contract else [ ];

  unknownOutputs = builtins.filter (output: !builtins.elem output outputs) contractOutputNames;

  contractHook = import ./contractHook.nix {
    inherit pkgs lib;
    errorPrefix = "withContract";
  } contract;
in
assert lib.assertMsg (unknownOutputs == [ ])
  "withContract: contract contains outputs not listed in the derivation: ${lib.concatStringsSep ", " unknownOutputs}";
drv.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ contractHook ];
  doInstallCheck = true;

  passthru = (old.passthru or { }) // {
    inherit contract;
  };
})
