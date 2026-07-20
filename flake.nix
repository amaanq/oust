{
  outputs =
    { self, ... }@args:
    let
      inputs = (import ./.tack) { overrides = args.tackOverrides or { }; };
      inherit (inputs) nixpkgs;
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.doubles.linux;
      pkgsFor = system: nixpkgs.legacyPackages.${system} or (import nixpkgs { inherit system; });

      extensionId = "akpcbccmelaffipdnfbmkjpalemmpnpp";
      hostName = "com.manic.oust";
      updateUrl = "https://github.com/amaanq/oust/releases/latest/download/updates.xml";
    in
    {
      inherit extensionId hostName updateUrl;

      overlays.default = final: _: {
        oust-host =
          final.runCommand "oust-host"
            {
              nativeBuildInputs = [ final.makeWrapper ];
              meta.mainProgram = "oust-host";
            }
            ''
              install -Dm644 ${./host/host.nu} $out/share/oust/host.nu
              makeWrapper ${final.lib.getExe final.nushell} $out/bin/oust-host \
                --add-flags $out/share/oust/host.nu \
                --prefix PATH : ${
                  final.lib.makeBinPath [
                    final.coreutils
                    final.util-linux
                  ]
                }
            '';
      };

      packages = forAllSystems (
        system:
        let
          pkgs = (pkgsFor system).extend self.overlays.default;
        in
        {
          inherit (pkgs) oust-host;
          default = pkgs.oust-host;
        }
      );

      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          options.programs.oust.enable = lib.mkEnableOption "the oust native messaging host";

          config = lib.mkIf config.programs.oust.enable {
            environment.etc."chromium/native-messaging-hosts/${hostName}.json".text = builtins.toJSON {
              name = hostName;
              description = "oust, hands escaped web app links to xdg-open";
              path = lib.getExe (pkgs.oust-host or self.packages.${pkgs.stdenv.hostPlatform.system}.oust-host);
              type = "stdio";
              allowed_origins = [ "chrome-extension://${extensionId}/" ];
            };
          };
        };
    };
}
