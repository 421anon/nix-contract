{ pkgs, lib, ... }:

rawContract: drv:

let
  outputs = drv.outputs or [ "out" ];
  supportedFields = [ "files" ];

  contract = rawContract;
  contractOutputNames = builtins.attrNames contract;

  unknownOutputs = builtins.filter (output: !builtins.elem output outputs) contractOutputNames;

  nonAttrOutputContracts = builtins.filter (
    output: !builtins.isAttrs contract.${output}
  ) contractOutputNames;

  unsupportedContractFields = lib.concatMap (
    output:
    builtins.map (name: "${output}.${name}") (
      builtins.filter (name: !builtins.elem name supportedFields) (builtins.attrNames contract.${output})
    )
  ) contractOutputNames;

  filesForOutput = output: contract.${output}.files or [ ];

  outputsWithNonListFiles = builtins.filter (
    output: !builtins.isList (filesForOutput output)
  ) contractOutputNames;

  fileEntries = lib.concatMap (
    output: builtins.map (file: { inherit output file; }) (filesForOutput output)
  ) contractOutputNames;

  nonStringFiles = builtins.filter (entry: !builtins.isString entry.file) fileEntries;

  hookSuffix = builtins.substring 0 12 (builtins.hashString "sha256" (builtins.toJSON contract));
  hookFunction = "nixContractsCheckFiles_${hookSuffix}";

  checkOutput =
    output:
    let
      outputVar = "$" + output;
    in
    ''
      echo "checking nix-contracts files for output '${output}'"
      ${lib.concatMapStringsSep "\n" (file: ''
        test -e "${outputVar}"/${lib.escapeShellArg file} || {
          printf '%s\n' ${lib.escapeShellArg "contract failed: missing file ${output}/${file}"} >&2
          exit 1
        }
      '') (filesForOutput output)}
    '';

  contractHook = pkgs.writeTextFile {
    name = "nix-contracts-files-hook";
    destination = "/nix-support/setup-hook";
    text = ''
      preInstallCheckHooks+=(${hookFunction})

      ${hookFunction}() {
        ${lib.concatMapStringsSep "\n" checkOutput contractOutputNames}
      }
    '';
  };
in
assert lib.assertMsg (unknownOutputs == [ ])
  "withContract: contract contains outputs not listed in the derivation: ${lib.concatStringsSep ", " unknownOutputs}";
assert lib.assertMsg (nonAttrOutputContracts == [ ])
  "withContract: each output contract must be an attribute set: ${lib.concatStringsSep ", " nonAttrOutputContracts}";
assert lib.assertMsg (unsupportedContractFields == [ ])
  "withContract: contract contains unsupported fields: ${lib.concatStringsSep ", " unsupportedContractFields}";
assert lib.assertMsg (outputsWithNonListFiles == [ ])
  "withContract: files must be a list for each output: ${lib.concatStringsSep ", " outputsWithNonListFiles}";
assert lib.assertMsg (nonStringFiles == [ ]) "withContract: every file must be a string";
drv.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ contractHook ];
  doInstallCheck = true;

  passthru = (old.passthru or { }) // {
    inherit contract;
  };
})
