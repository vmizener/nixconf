{
  flake.nixosModules."common/options" = {
    config,
    lib,
    ...
  }: {
    options.features.greeter = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to run for the greetd default session";
      };
    };

    # config = {
    #   assertions = [
    #     {
    #       assertion = config.services.greetd.enable;
    #       message = "Any feat/greeter module requires a login manager (such as feat/login-manager/greetd) to be enabled.";
    #     }
    #   ];
    # };
  };
}
