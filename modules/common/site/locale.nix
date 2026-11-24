/*
  common/site/locale

Site-wide default time zone and POSIX locale options (`options.site.locale`).
*/
{lib, ...}: {
  options.site.locale = {
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "Default site-wide IANA time zone (populated from `[locale].time_zone` in `site.meta.configFiles`).";
    };
    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "Default site-wide POSIX locale (populated from `[locale].default_locale` in `site.meta.configFiles`).";
    };
  };
}
