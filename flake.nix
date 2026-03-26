{
  description = "Enhanced Proxmox MCP Server - A Model Context Protocol server for Proxmox virtualization management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python311;

        proxmox-mcp-plus = python.pkgs.buildPythonApplication {
          pname = "proxmox-mcp-plus";
          version = "0.1.0";
          format = "pyproject";

          src = pkgs.lib.cleanSource ./.;

          nativeBuildInputs = with python.pkgs; [
            hatchling
          ];

          propagatedBuildInputs = with python.pkgs; [
            requests
            pydantic
            fastapi
            paramiko
            anyio
            uvicorn
            # These may need to be added or overridden
            (python.pkgs.proxmoxer or (python.pkgs.buildPythonPackage rec {
              pname = "proxmoxer";
              version = "2.0.1";
              src = python.pkgs.fetchPypi {
                inherit pname version;
                sha256 = pkgs.lib.fakeHash;
              };
              propagatedBuildInputs = [ python.pkgs.requests ];
              doCheck = false;
            }))
          ];

          nativeCheckInputs = with python.pkgs; [
            pytest
            pytest-asyncio
            pytestCheckHook
          ];

          # Run pytest in check phase
          pytestFlagsArray = [
            "tests/"
            "-v"
          ];

          # Skip integration tests that need actual Proxmox
          preCheck = ''
            export HOME=$(mktemp -d)
          '';

          pythonImportsCheck = [ "proxmox_mcp" ];

          meta = with pkgs.lib; {
            description = "Enhanced MCP server for Proxmox virtualization management";
            longDescription = ''
              ProxmoxMCP-Plus provides comprehensive Proxmox management including:
              - VM lifecycle management
              - LXC container support
              - Snapshot and backup management
              - OpenAPI REST endpoints
            '';
            homepage = "https://github.com/stfl/ProxmoxMCP-Plus";
            license = licenses.mit;
            mainProgram = "proxmox-mcp";
          };
        };

      in
      {
        packages.default = proxmox-mcp-plus;

        apps.default = {
          type = "app";
          program = "${proxmox-mcp-plus}/bin/proxmox-mcp";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with python.pkgs; [
            python
            hatchling
            pip
            pytest
            pytest-asyncio
            black
            mypy
            ruff
            types-requests
          ];

          shellHook = ''
            echo "================================================"
            echo "ProxmoxMCP-Plus Development Environment"
            echo "================================================"
            echo "Python: $(python --version)"
            echo ""
            echo "Commands:"
            echo "  pytest tests/         - Run tests"
            echo "  python -m proxmox_mcp.server - Run server"
            echo "  nix build             - Build package"
            echo "  nix run               - Run package"
            echo "================================================"
          '';
        };
      }
    );
}
