{
  description = "PostgreSQL database environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      PGRUNDIR = "/tmp/pg_$(id -u)";
      PGDATA = "./.pgdata";
      PGPORT = "5432";
      DB_USER = "dbuser"; # Must be lowercase
      DB_PASSWORD = "dbpass"; # Must be lowercase
      DB_NAME = "dev"; # Must be lowercase
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          postgresql
        ];

        shellHook = ''
            export PGDATA="${PGDATA}"
            export PGPORT="${PGPORT}"
            export DB_USER="${DB_USER}"
            export DB_PASSWORD="${DB_PASSWORD}"
            export DB_NAME="${DB_NAME}"
            export PGRUNDIR="${PGRUNDIR}"

            mkdir -p "$PGRUNDIR"
            chmod 700 "$PGRUNDIR"

            # Function to check PostgreSQL readiness
            wait_for_postgres() {
              for i in {1..10}; do
                if pg_ctl status > /dev/null 2>&1; then
                  return 0
                fi
                sleep 1
              done
              echo "❌ PostgreSQL did not start within 10 seconds"
              return 1
            }

            # Initialize database if needed
            if [ ! -d "$PGDATA" ] || [ ! -f "$PGDATA/PG_VERSION" ]; then
              echo "Initializing PostgreSQL database..."
              rm -rf "$PGDATA"
              initdb --auth=trust --no-locale || { echo "initdb failed"; exit 1; }

              # Configure socket directory and port
              cat >> "$PGDATA/postgresql.conf" <<EOF
          unix_socket_directories = '${PGRUNDIR}'
          listen_addresses = 'localhost'
          port = ${PGPORT}
          EOF

              # Set authentication: trust for local socket, md5 for TCP
              cat > "$PGDATA/pg_hba.conf" <<EOF
          local all all trust
          host  all all 127.0.0.1/32 md5
          host  all all ::1/128      md5
          EOF

              echo "Starting temporary PostgreSQL instance..."
              pg_ctl start -l "$PGDATA/postgres.log" -w -o "-k ${PGRUNDIR}" || {
                echo "❌ Failed to start PostgreSQL. Last 20 lines of log:"
                tail -20 "$PGDATA/postgres.log"
                exit 1
              }

              # Wait a moment to ensure socket is ready
              wait_for_postgres || exit 1

              echo "Creating superuser '$DB_USER' and database '$DB_NAME'..."
              psql -h "$PGRUNDIR" postgres -c "CREATE USER $DB_USER WITH SUPERUSER CREATEDB CREATEROLE LOGIN PASSWORD '$DB_PASSWORD';" || {
                echo "❌ Failed to create user. Check the log above."
                pg_ctl stop
                exit 1
              }

              psql -h "$PGRUNDIR" postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" || {
                echo "❌ Failed to create database."
                pg_ctl stop
                exit 1
              }

              # Grant additional privileges
              psql -h "$PGRUNDIR" -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
              psql -h "$PGRUNDIR" -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;"
              psql -h "$PGRUNDIR" -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;"
              psql -h "$PGRUNDIR" -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;"
              psql -h "$PGRUNDIR" -d "$DB_NAME" -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO $DB_USER;"

              echo "Stopping temporary instance..."
              pg_ctl stop || echo "Warning: stop failed, but continuing."
              echo "✅ Database initialized successfully!"
            fi

            # Start the main instance if not already running
            if ! pg_ctl status > /dev/null 2>&1; then
              echo "Starting PostgreSQL..."
              if pg_ctl start -l "$PGDATA/postgres.log" -w -o "-k $PGRUNDIR"; then
                echo "✅ PostgreSQL started. Connection details:"
                echo "  URL: postgresql://$DB_USER:$DB_PASSWORD@localhost:$PGPORT/$DB_NAME"
                echo "  Local socket: psql -h $PGRUNDIR -U $DB_USER -d $DB_NAME"
              else
                echo "❌ Failed to start PostgreSQL. Check the log:"
                tail -20 "$PGDATA/postgres.log"
                exit 1
              fi
            else
              echo "✅ PostgreSQL is already running."
              echo "  URL: postgresql://$DB_USER:$DB_PASSWORD@localhost:$PGPORT/$DB_NAME"
              echo "  Local socket: psql -h $PGRUNDIR -U $DB_USER -d $DB_NAME"
            fi
        '';
      };

      apps = {
        stop = {
          type = "app";
          program = toString (pkgs.writeShellScript "stop-postgres" ''
            export PGDATA=${PGDATA}
            ${pkgs.postgresql}/bin/pg_ctl stop
          '');
        };

        # Reset the database (warning: deletes all data)
        reset = {
          type = "app";
          program = toString (pkgs.writeShellScript "reset-postgres" ''
            export PGDATA=${PGDATA}
            export PGRUNDIR=${PGRUNDIR}
            if ${pkgs.postgresql}/bin/pg_ctl status > /dev/null 2>&1; then
              ${pkgs.postgresql}/bin/pg_ctl stop
            fi
            rm -rf "$PGDATA"
            echo "Database reset complete. Run 'nix develop' to reinitialize."
          '');
        };
      };
    });
}
