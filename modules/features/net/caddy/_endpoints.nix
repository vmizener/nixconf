# Upstream endpoint parsing and IP/loopback literal predicates for `feat/net/caddy`.
{lib}: let
  isLoopbackHost = h: builtins.elem h ["localhost" "127.0.0.1" "::1"];
  isIpv4Literal = h: builtins.match "^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$" h != null;
  isIpv6Literal = h: lib.hasInfix ":" h && builtins.match "^[0-9a-fA-F:]+$" h != null;
in {
  inherit isIpv4Literal isIpv6Literal isLoopbackHost;

  isValidSandboxHost = h: isLoopbackHost h || isIpv4Literal h || isIpv6Literal h;

  parseEndpoint = raw: let
    stripped =
      raw
      |> lib.removePrefix "http://"
      |> lib.removePrefix "https://";
    hostAndPort = builtins.head (lib.splitString "/" stripped);
    ipv6Parts = lib.splitString "]:" (lib.removePrefix "[" hostAndPort);
    ipv4Match = builtins.match "^([^:]+):([0-9]+)$" hostAndPort;
  in
    if
      lib.hasPrefix "[" hostAndPort
      && builtins.length ipv6Parts == 2
      && builtins.match "^[0-9]+$" (builtins.elemAt ipv6Parts 1) != null
    then {
      host = builtins.elemAt ipv6Parts 0;
      port = lib.toInt (builtins.elemAt ipv6Parts 1);
    }
    else if ipv4Match != null
    then {
      host = builtins.elemAt ipv4Match 0;
      port = lib.toInt (builtins.elemAt ipv4Match 1);
    }
    else null;
}
