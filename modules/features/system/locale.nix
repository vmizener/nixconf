/*
  feat/system/locale

Sets up default system time zone and locale settings.

Exposes:

- flake.nixosModules."common/options" (options.mod."feat/system/locale")
- flake.nixosModules."feat/system/locale":
*/
{...} @ flake: let
  moduleName = "feat/system/locale";
in {
  flake.nixosModules."common/options" = {lib, ...}: {
    options.mod.${moduleName} = {
      timeZone = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = flake.config.inventory.siteConfig.locale.timeZone;
        defaultText = lib.literalExpression "inventory.siteConfig.locale.timeZone";
        description = "System IANA time zone configured as `time.timeZone` (`null` leaves `time.timeZone` unset).";
      };
      defaultLocale = lib.mkOption {
        type = lib.types.str;
        default = flake.config.inventory.siteConfig.locale.defaultLocale;
        defaultText = lib.literalExpression "inventory.siteConfig.locale.defaultLocale";
        description = "Default system locale applied to `i18n.defaultLocale` and `i18n.extraLocaleSettings`.";
      };
    };
  };

  flake.nixosModules.${moduleName} = {
    config,
    lib,
    ...
  }: let
    cfg = config.mod.${moduleName};
  in {
    mod.meta.imported = [moduleName];
    time.timeZone = lib.mkIf (cfg.timeZone != null) (lib.mkDefault cfg.timeZone);
    i18n = {
      defaultLocale = lib.mkDefault cfg.defaultLocale;
      extraLocaleSettings = lib.genAttrs [
        "LC_ADDRESS"
        "LC_IDENTIFICATION"
        "LC_MEASUREMENT"
        "LC_MONETARY"
        "LC_NAME"
        "LC_NUMERIC"
        "LC_PAPER"
        "LC_TELEPHONE"
        "LC_TIME"
      ] (_: lib.mkDefault cfg.defaultLocale);
    };
  };
}
