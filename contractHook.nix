{ pkgs, lib, errorPrefix ? "contractHook", ... }:

rawContract:

let
  supportedFields = [ "files" ];

  contract = rawContract;
  contractIsAttrs = builtins.isAttrs contract;
  contractOutputNames = if contractIsAttrs then builtins.attrNames contract else [ ];
  attrOutputNames = builtins.filter (output: builtins.isAttrs contract.${output}) contractOutputNames;

  nonAttrOutputContracts = builtins.filter (
    output: !builtins.isAttrs contract.${output}
  ) contractOutputNames;

  unsupportedContractFields = lib.concatMap (
    output:
    builtins.map (name: "${output}.${name}") (
      builtins.filter (name: !builtins.elem name supportedFields) (builtins.attrNames contract.${output})
    )
  ) attrOutputNames;

  filesForOutput = output: contract.${output}.files or [ ];

  outputsWithNonListFiles = builtins.filter (
    output: !builtins.isList (filesForOutput output)
  ) attrOutputNames;

  outputsWithListFiles = builtins.filter (
    output: builtins.isList (filesForOutput output)
  ) attrOutputNames;

  fileEntries = lib.concatMap (
    output: builtins.map (file: { inherit output file; }) (filesForOutput output)
  ) outputsWithListFiles;

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
in
assert lib.assertMsg contractIsAttrs "${errorPrefix}: contract must be an attribute set";
assert lib.assertMsg (nonAttrOutputContracts == [ ])
  "${errorPrefix}: each output contract must be an attribute set: ${lib.concatStringsSep ", " nonAttrOutputContracts}";
assert lib.assertMsg (unsupportedContractFields == [ ])
  "${errorPrefix}: contract contains unsupported fields: ${lib.concatStringsSep ", " unsupportedContractFields}";
assert lib.assertMsg (outputsWithNonListFiles == [ ])
  "${errorPrefix}: files must be a list for each output: ${lib.concatStringsSep ", " outputsWithNonListFiles}";
assert lib.assertMsg (nonStringFiles == [ ]) "${errorPrefix}: every file must be a string";
pkgs.writeTextFile {
  name = "nix-contracts-files-hook";
  destination = "/nix-support/setup-hook";
  text = ''
    preInstallCheckHooks+=(${hookFunction})

    ${hookFunction}() {
      ${lib.concatMapStringsSep "\n" checkOutput contractOutputNames}
    }
  '';
}
