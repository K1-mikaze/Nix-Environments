{
  description = "PostgreSQL database environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      dbUser = "nix";
      dbPassword = "123";
      dbName = "NixDB";
      dbPort = "5432";
      dbRunDir = "/tmp/pg_$(id -u)";
      dbData = "$PWD/.pgdata";
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          postgresql
        ];

        shellHook = ''
          export PGDATA=${dbData}
          export PGPORT=${dbPort}

          # Database credentials
          export DB_USER=${dbUser}
          export DB_PASSWORD=${dbPassword}
          export DB_NAME=${dbName}

          # Create the system directory PostgreSQL expects for locks
          export PGRUNDIR=${dbRunDir}
          mkdir -p "$PGRUNDIR"
          chmod 700 "$PGRUNDIR"

          # Check if database is properly initialized
          if [ ! -d "$PGDATA" ] || [ ! -f "$PGDATA/PG_VERSION" ]; then
            echo "Initializing PostgreSQL database..."
            rm -rf "$PGDATA"
            initdb --auth=trust --no-locale

            # Configure to use our custom runtime directory
            echo "unix_socket_directories = '$PGRUNDIR'" >> "$PGDATA/postgresql.conf"
            echo "listen_addresses = 'localhost'" >> "$PGDATA/postgresql.conf"
            echo "port = $PGPORT" >> "$PGDATA/postgresql.conf"

            # Update authentication to use md5 (password) instead of trust
            echo "local all all trust" >> "$PGDATA/pg_hba.conf"
            echo "host all all 127.0.0.1/32 md5" >> "$PGDATA/pg_hba.conf"
            echo "host all all ::1/128 md5" >> "$PGDATA/pg_hba.conf"

            echo "Database initialized successfully!"

            # Start PostgreSQL temporarily to create user and database
            echo "Starting PostgreSQL to create user and database..."
            pg_ctl start -l "$PGDATA/postgres.log" -w -o "-k $PGRUNDIR"

            # Create superuser with all privileges
            echo "Creating superuser '$DB_USER' with all privileges..."
            psql -h "$PGRUNDIR" postgres -c "CREATE USER $DB_USER WITH SUPERUSER CREATEDB CREATEROLE LOGIN PASSWORD '$DB_PASSWORD';"

            # Create database owned by the user
            psql -h "$PGRUNDIR" postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"

            # Grant all privileges on the database
            psql -h "$PGRUNDIR" postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

            # Grant permissions to create schemas and other objects
            psql -h "$PGRUNDIR" $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO $DB_USER;"

            echo "Superuser created with all permissions!"

            # Stop PostgreSQL after setup
            pg_ctl stop
            echo "Database setup complete!"
          fi

          # Start PostgreSQL with explicit socket directory
          if ! pg_ctl status > /dev/null 2>&1; then
            echo "Starting PostgreSQL..."
            echo "Using runtime directory: $PGRUNDIR"

            if pg_ctl start -l "$PGDATA/postgres.log" -w -o "-k $PGRUNDIR"; then
              echo "PostgreSQL started successfully!"
              echo "Database: $DB_NAME"
              echo "Username: $DB_USER (SUPERUSER)"
              echo "Password: $DB_PASSWORD"
              echo "Port: $PGPORT"
              echo ""
              echo "Database Information in: $PGDATA"
              echo ""
              echo "Connection strings:"
              echo "  URL: postgresql://$DB_USER:$DB_PASSWORD@localhost:$PGPORT/$DB_NAME"
              echo ""
              echo "Connect with: psql -h $PGRUNDIR -U $DB_USER -d $DB_NAME"
            else
              echo "Failed to start PostgreSQL. Check the log:"
              cat "$PGDATA/postgres.log"
            fi
          else
            echo "PostgreSQL is already running"
          fi
        '';
      };

      apps = {
        stop = {
          type = "app";
          program = toString (pkgs.writeShellScript "stop-postgres" ''
            export PGDATA="$PWD/.pgdata"
            pg_ctl stop
          '');
        };

        # Grant additional permissions to existing user
        grant-permissions = {
          type = "app";
          program = toString (pkgs.writeShellScript "grant-permissions" ''
            export PGRUNDIR="/tmp/pg_$(id -u)"
            export DB_USER=${dbUser}
            export DB_NAME=${dbName}

            echo "Granting superuser privileges to $DB_USER..."
            psql -h "$PGRUNDIR" postgres -c "ALTER USER $DB_USER WITH SUPERUSER CREATEDB CREATEROLE;"
            psql -h "$PGRUNDIR" $DB_NAME -c "GRANT ALL ON SCHEMA public TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;"
            psql -h "$PGRUNDIR" $DB_NAME -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;"
            echo "All permissions granted to $DB_USER!"
          '');
        };

        # Reset the database (warning: deletes all data)
        reset = {
          type = "app";
          program = toString (pkgs.writeShellScript "reset-postgres" ''
            export PGDATA="$PWD/.pgdata"
            export PGRUNDIR="/tmp/pg_$(id -u)"
            if pg_ctl status > /dev/null 2>&1; then
              pg_ctl stop
            fi
            rm -rf "$PGDATA"
            echo "Database reset complete."
          '');
        };
      };
    });
}
