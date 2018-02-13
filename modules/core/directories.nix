{ lib, config, ... }:

let
  inherit (lib) types;

  permConfToRWX = isDir: cfg: let
    execAttr = if isDir then "search" else "execute";
    fullBits = if isDir then "rwx" else "rw${execBit}";
    mkBit = val: bit: if val then bit else "-";
    readBit = mkBit cfg.read "r";
    writeBit = mkBit cfg.write "w";
    execBit = mkBit cfg.${execAttr} "x";
  in if cfg.fullAccess then fullBits
     else if cfg.noAccess then "---"
     else readBit + writeBit + execBit;

  mkPermOpts = { descCan, descHas, descIsDenied, isDir
               , read ? true, write ? true, execute ? true
               }: let
    extraDesc = lib.optionalString (!isDir) ''
      These permissions are set only for <emphasis>files</emphasis> and not
      directories and are only set/changed during startup
      <emphasis>and</emphasis> whenever <option>recursive</option> is set to
      <literal>true</literal> on a specific directory.
    '';
    dirOrFile = if isDir then "directory" else "file";
    execAttr = if isDir then "search" else "execute";
    andOpt = values: let
      mkOpt = opt: "<option>${opt}</option>";
      left = lib.concatMapStringsSep ", " mkOpt (lib.init values);
      right = mkOpt (lib.last values);
      xAnd = lib.optionalString (lib.length values > 1) "${left} and ";
    in lib.optionalString (values != []) (xAnd + right);
    attrsInvolved = [ "read" "write" ] ++ lib.optional isDir execAttr;
  in {
    read = lib.mkOption {
      type = types.bool;
      default = read;
      example = !read;
      description = ''
        Whether ${descCan} read the contents of the ${dirOrFile}.
      '' + extraDesc;
    };

    write = lib.mkOption {
      type = types.bool;
      default = write;
      example = !write;
      description = (if isDir then ''
        Whether ${descCan} add new entries to the directory.
      '' else ''
        Whether ${descCan} alter the file's contents.
      '') + extraDesc;
    };

    ${execAttr} = lib.mkOption {
      type = types.bool;
      default = execute;
      example = !execute;
      description = (if isDir then ''
        Whether ${descCan} list the contents of the directory.
      '' else ''
        Whether ${descCan} execute the file.
      '') + extraDesc;
    };

    fullAccess = lib.mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether ${descHas} full access to the ${dirOrFile}, which is a
        short-hand of setting ${andOpt attrsInvolved} to
        <literal>true</literal>.
      '' + extraDesc + ''
        Note that setting this takes precedence over setting any of the
        ${andOpt (attrsInvolved ++ [ "noAccess" ])} options.
      '';
    };

    noAccess = lib.mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether ${descIsDenied} access to the ${dirOrFile}, which is a
        short-hand of setting ${andOpt [ "read" "write" execAttr ]} to
        <literal>false</literal>.
      '' + extraDesc + ''
        Note that setting this takes precedence over setting any of the
        ${andOpt [ "read" "write" execAttr ]} options.
      '';
    };
  };

  mkDirPermOpts = attrs: {
    filePerms = mkPermOpts (attrs // { isDir = false; execute = false; });
  } // mkPermOpts (attrs // { isDir = true; });

  dirModule.options = {
    create = lib.mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether to create the directory during startup.";
    };

    before = lib.mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "my-shiny.service" ];
      description = ''
        The systemd units which require this directory, so creation or fixup
        should be done prior to the startup of these units.
      '';
    };

    owner = lib.mkOption {
      type = types.str;
      default = "root";
      example = "nobody";
      description = ''
        The owner of the directory which is able to set permissions and ACLs.
      '';
    };

    group = lib.mkOption {
      type = types.str;
      default = "root";
      example = "nogroup";
      description = "The group owning the directory.";
    };

    permissions = {
      recursive = lib.mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = ''
          Whether to fixup permissions recursively during instance startup.
        '';
      };

      owner = mkDirPermOpts {
        descCan = "the owner can";
        descHas = "the owner has";
        descIsDenied = "the owner is denied";
      };

      group = mkDirPermOpts {
        descCan = "the group can";
        descHas = "the group has";
        descIsDenied = "the group is denied";
        write = false;
      };

      others = mkDirPermOpts {
        descCan = "others can";
        descHas = "others have";
        descIsDenied = "others are denied";
        write = false;
      };
    };

    users = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = mkDirPermOpts {
          descCan = "the user can";
          descHas = "the user has";
          descIsDenied = "the user is denied";
        };
      });
      default = {};
      example.foo.write = false;
      description = ''
        Additional users with access to the directory along with permissions.
        The attribute names are the users and the submodule options specify its
        permissions.
      '';
    };

    groups = lib.mkOption {
      type = types.attrsOf (types.submodule {
        options = mkDirPermOpts {
          descCan = "the group can";
          descHas = "the group has";
          descIsDenied = "the group is denied";
          write = false;
        };
      });
      default = {};
      example.bar.write = false;
      description = ''
        Additional groups with access to the directory along with permissions.
        The attribute names are the groups and the submodule options specify
        its permissions.
      '';
    };
  };

  splitPath = path: let
    result = builtins.match "([^/]*)/(.*)" path;
    iter = [ (lib.head result) ] ++ splitPath (lib.last result);
  in if result == null then [ path ] else iter;

  sanitizePath = path: let
    splitted = splitPath path;
    filtered = lib.filter (c: c != "" && c != "." && c != "..") splitted;
  in lib.concatStringsSep "/" filtered;

  mkDir = path: cfg: let
    absPath = "/${path}";

    escPath = let
      unsafeChars = [ "@" ":" "\\" "[" "]" "/" "." ];
      safeChars = map (lib.const "-") unsafeChars;
    in lib.replaceStrings unsafeChars safeChars path;

    mkService = name: desc: attrs: {
      name = "${name}-${escPath}";
      value = {
        description = "${desc} ${absPath}";
        wantedBy = [ "multi-user.target" ];
        inherit (cfg) before;
      } // attrs;
    };

    mkCmd = lib.concatMapStringsSep " " lib.escapeShellArg;

    recurseScript = ""; # TODO!

    dirACL = let
      perms = [
        "u:${cfg.owner}:${permConfToRWX true cfg.permissions.owner}"
        "g:${cfg.group}:${permConfToRWX true cfg.permissions.group}"
        "o::${permConfToRWX true cfg.permissions.others}"
      ];
      defPerms = map (p: "d:${p}") perms;
    in lib.concatStringsSep "," (defPerms ++ perms);

    setOwner = mkCmd [ "chown" cfg.owner cfg.group absPath ];
    setPerms = mkCmd [ "setfacl" "-b" "-m" dirACL absPath ];

    createService = mkService "mkdir" "Create Directory" {
      script = lib.concatStringsSep "\n" [
        (mkCmd [ "mkdir" "-m" "0000" "-p" absPath ])
        setOwner setPerms
      ];
      unitConfig.ConditionPathExists = "!${absPath}";
    };

    fixupService = mkService "fixup" "Fixup Permissions for Directory" {
      script = lib.concatStringsSep "\n" [ setOwner setPerms ];
      unitConfig.ConditionPathExists = "${absPath}";
    };

  in [ fixupService ] ++ lib.optional cfg.create createService;

in {
  options.nixcloud.directories = lib.mkOption {
    type = types.attrsOf (types.submodule dirModule);
    default = {};
    example."foo/bar".before = [ "my-shiny.service" ];
    example."foo/bar".owner = "shiny";
    example."foo/bar".group = "shinyones";
    apply = lib.mapAttrs' (path: value: {
      name = sanitizePath path;
      inherit value;
    });
    description = ''
      Directories to create and set permissions for.

      The attribute names are <emphasis>always</emphasis> absolute paths and
      components such as <literal>.</literal> and <literal>..</literal> are
      stripped out.

      Also the paths don't need to start with a <literal>/</literal>, because
      that's already implied.
    '';
  };

  config = lib.mkIf (config.nixcloud.directories != {}) {
    systemd.services = let
      serviceList = lib.mapAttrsToList mkDir config.nixcloud.directories;
    in lib.listToAttrs (lib.concatLists serviceList);
  };
}
