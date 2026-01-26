{
  description = "Flake to manage elegant grub2 themes from vinceliuice";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    with nixpkgs.lib;
    rec {
      nixosModules.default = { config, ... }:
        let
          cfg = config.boot.loader.elegant-grub2-theme;
          splashImage = if cfg.splashImage == null then "" else cfg.splashImage;
          resolutions = {
            "1080p" = "1920x1080";
            "2k" = "2560x1440";
            "4k" = "3840x2160";
          };
          
          # The generate script creates: Elegant-${theme}-${type}-${side}-${color}
          themeName = "Elegant-${cfg.theme}-${cfg.type}-${cfg.side}-${cfg.color}";
          
          elegant-grub2-theme = pkgs.stdenv.mkDerivation {
            name = "elegant-grub2-theme";
            src = "${self}";
            buildInputs = [ pkgs.imagemagick ];
            installPhase = ''
              mkdir -p $out/grub/themes
              
              # Generate theme
              bash ./generate.sh \
                -d "$out/grub/themes" \
                -t ${cfg.theme} \
                -p ${cfg.type} \
                -i ${cfg.side} \
                -c ${cfg.color} \
                -s ${cfg.screen} \
                -l ${cfg.logo}
              
              ${if cfg.splashImage != null then ''
                # Find the generated theme directory and replace background
                theme_dir=$(find $out/grub/themes -maxdepth 1 -type d -name "Elegant-*" | head -n 1)
                if [ -n "$theme_dir" ] && [ -f "$theme_dir/background.jpg" ]; then
                  rm -f "$theme_dir/background.jpg"
                  ${pkgs.imagemagick}/bin/convert ${cfg.splashImage} "$theme_dir/background.jpg"
                fi
              '' else ""}
            '';
          };
          
          resolution = resolutions."${cfg.screen}";
        in
        rec {
          options = {
            boot.loader.elegant-grub2-theme = {
              enable = mkOption {
                default = false;
                example = true;
                type = types.bool;
                description = ''
                  Enable elegant grub2 theming
                '';
              };
              theme = mkOption {
                default = "forest";
                example = "forest";
                type = types.enum [ "forest" "mojave" "mountain" "wave" ];
                description = ''
                  Background theme variant to use for grub2.
                '';
              };
              type = mkOption {
                default = "window";
                example = "window";
                type = types.enum [ "window" "float" "sharp" "blur" ];
                description = ''
                  Theme style variant to use for grub2.
                '';
              };
              side = mkOption {
                default = "left";
                example = "left";
                type = types.enum [ "left" "right" ];
                description = ''
                  Picture display side for grub2.
                '';
              };
              color = mkOption {
                default = "dark";
                example = "dark";
                type = types.enum [ "dark" "light" ];
                description = ''
                  Background color variant to use for grub2.
                '';
              };
              screen = mkOption {
                default = "1080p";
                example = "1080p";
                type = types.enum [ "1080p" "2k" "4k" ];
                description = ''
                  The screen display variant to use for grub2.
                '';
              };
              logo = mkOption {
                default = "default";
                example = "default";
                type = types.enum [ "default" "system" ];
                description = ''
                  Logo variant to use for grub2.
                '';
              };
              splashImage = mkOption {
                default = null;
                example = "/my/path/background.jpg";
                type = types.nullOr types.path;
                description = ''
                  The path of the image to use for background (must be jpg or png).
                '';
              };
            };
          };
          config = mkIf cfg.enable (mkMerge [{
            environment.systemPackages = [
              elegant-grub2-theme
            ];
            boot.loader.grub = {
              theme = "${elegant-grub2-theme}/grub/themes/${themeName}";
              splashImage = "${elegant-grub2-theme}/grub/themes/${themeName}/background.jpg";
              gfxmodeEfi = "${resolution},auto";
              gfxmodeBios = "${resolution},auto";
              extraConfig = ''
                insmod gfxterm
                insmod png
              '';
            };
          }]);
        };
    };
}
