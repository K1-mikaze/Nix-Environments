{
  description = "MariaDB Database Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        DB_USER = "mariadb";
        DB_PASSWORD = "mariadb";
        DB_PORT = "3306";
        DB_NAME = "mariadb";

        mariadbBin = "${pkgs.mariadb}/bin";
        mariadbFlags = builtins.concatStringsSep " \\\n    " [
          "--datadir=\"$DB_DATA_DIR\""
          "--socket=\"$DB_SOCKET_DIR/mariadb.sock\""
          "--port=\"$DB_PORT\""
          "--pid-file=\"$DB_SOCKET_DIR/mariadb.pid\""
          "--log-error=\"$DB_DATA_DIR/error.log\""
          "--bind-address=0.0.0.0"
          "--skip-networking=0"
          "--innodb-buffer-pool-size=128M"
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            mariadb
            gnused
            procps
            netcat
          ];

          shellHook = ''
            export DB_DATA_DIR="$PWD/.mdbdata"
            export DB_SOCKET_DIR="/tmp/mariadb_$(id -u)"
            export DB_PORT=${DB_PORT}

            # Database credentials
            export DB_USER=${DB_USER}
            export DB_PASSWORD=${DB_PASSWORD}
            export DB_NAME=${DB_NAME}

            # Create directories
            mkdir -p "$DB_SOCKET_DIR"
            mkdir -p "$DB_DATA_DIR"
            chmod 700 "$DB_SOCKET_DIR"

            # Function to check if database process is running
            db_process_running() {
              [ -f "$DB_SOCKET_DIR/mariadb.pid" ] && ps -p $(cat "$DB_SOCKET_DIR/mariadb.pid") > /dev/null 2>&1
            }

            # Function to check if database is ready via TCP
            db_ready_tcp() {
              nc -z 127.0.0.1 $DB_PORT > /dev/null 2>&1
            }

            # Clean up existing processes
            echo "🧹 Cleaning up existing MariaDB processes..."
            if [ -f "$DB_SOCKET_DIR/mariadb.pid" ]; then
              ${mariadbBin}/mariadb-admin -h 127.0.0.1 -P $DB_PORT -u root shutdown 2>/dev/null || true
              kill $(cat "$DB_SOCKET_DIR/mariadb.pid") 2>/dev/null || true
              rm -f "$DB_SOCKET_DIR/mariadb.pid"
            fi
            pkill -f "mariadbd.*datadir=$DB_DATA_DIR" 2>/dev/null || true
            sleep 2

            # Initialize if needed
            if [ ! -d "$DB_DATA_DIR/mysql" ]; then
              echo "📦 Initializing MariaDB..."
              ${mariadbBin}/mariadb-install-db \
                --auth-root-authentication-method=normal \
                --datadir="$DB_DATA_DIR" \
                --rpm

              echo "🚀 Starting MariaDB for initial setup..."
              ${mariadbBin}/mariadbd \
                ${mariadbFlags} \
                2>&1 &

              DB_PID=$!
              echo $DB_PID > "$DB_SOCKET_DIR/mariadb.pid"

              # Wait for startup
              echo -n "Waiting for database to be ready for setup"
              for i in {1..30}; do
                if db_process_running && db_ready_tcp; then
                  echo " - Ready!"
                  break
                fi
                sleep 1
                echo -n "."
                if [ $i -eq 30 ]; then
                  echo " - Timeout!"
                  exit 1
                fi
              done

              # Setup user and database with proper privileges
              echo "🔧 Setting up user and database..."
              mysql -h 127.0.0.1 -P $DB_PORT -u root -e "
                -- Create user with password
                CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
                CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';

                -- Create database
                CREATE DATABASE IF NOT EXISTS $DB_NAME;

                -- Grant all privileges on the database
                GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
                GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';

                -- Grant additional privileges for full superuser access
                GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'localhost' WITH GRANT OPTION;
                GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'%' WITH GRANT OPTION;

                -- System privileges
                GRANT SYSTEM_USER ON *.* TO '$DB_USER'@'localhost';
                GRANT SYSTEM_USER ON *.* TO '$DB_USER'@'%';

                FLUSH PRIVILEGES;
              " 2>/dev/null || echo "Initial setup completed"

              # Stop the temporary instance
              echo "Stopping temporary instance..."
              ${mariadbBin}/mariadb-admin -h 127.0.0.1 -P $DB_PORT -u root shutdown 2>/dev/null || true
              wait "$DB_PID" 2>/dev/null || true
              rm -f "$DB_SOCKET_DIR/mariadb.pid"
              sleep 2
            fi

            # Start MariaDB with proper networking
            echo "🚀 Starting MariaDB on port $DB_PORT..."
            ${mariadbBin}/mariadbd \
              ${mariadbFlags} \
              2>&1 &

            DB_PID=$!
            echo $DB_PID > "$DB_SOCKET_DIR/mariadb.pid"

            # Wait for startup with better diagnostics
            echo -n "Waiting for database to be ready"
            for i in {1..60}; do
              if db_process_running && db_ready_tcp; then
                echo " - Ready!"
                break
              fi
              if ! db_process_running; then
                echo " - Process died!"
                echo "Error log:"
                cat "$DB_DATA_DIR/error.log" 2>/dev/null || echo "No error log found"
                exit 1
              fi
              sleep 1
              echo -n "."
              if [ $i -eq 60 ]; then
                echo " - Timeout after 60 seconds!"
                echo "Error log:"
                cat "$DB_DATA_DIR/error.log" 2>/dev/null || echo "No error log found"
                exit 1
              fi
            done

            echo "MariaDB is ready and accessible!"
            echo ""
            echo "Connection Details:"
            echo "  Host: localhost"
            echo "  Port: $DB_PORT"
            echo "  Database: $DB_NAME"
            echo "  Username: $DB_USER"
            echo "  Password: $DB_PASSWORD"
            echo ""
            echo "Connection strings:"
            echo "  JDBC: jdbc:mysql://localhost:$DB_PORT/$DB_NAME"
            echo "  URL: postgresql://$DB_USER:$DB_PASSWORD@localhost:$DB_PORT/$DB_NAME"
            echo ""
            echo "Connect with: mysql -h 127.0.0.1 -P $DB_PORT -u $DB_USER -p$DB_PASSWORD $DB_NAME"
            echo ""

            trap '
              echo ""
              echo "🧹 Stopping MariaDB..."
              if [ -f "$DB_SOCKET_DIR/mariadb.pid" ]; then
                ${mariadbBin}/mariadb-admin -h 127.0.0.1 -P $DB_PORT -u root shutdown 2>/dev/null || true
                ${mariadbBin}/mariadb-admin -h 127.0.0.1 -P $DB_PORT -u $DB_USER -p$DB_PASSWORD shutdown 2>/dev/null || true
                kill $(cat "$DB_SOCKET_DIR/mariadb.pid") 2>/dev/null || true
                rm -f "$DB_SOCKET_DIR/mariadb.pid"
                echo "✅ MariaDB stopped"
              fi
            ' EXIT
          '';
        };

        apps = {
          mariadb-stop = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "stop-mariadb" ''
                export DB_SOCKET_DIR="/tmp/mariadb_$(id -u)"
                export DB_PORT=${DB_PORT}
                export DB_USER=${DB_USER}
                export DB_PASSWORD=${DB_PASSWORD}

                echo "🧹 Stopping MariaDB..."
                if [ -f "$DB_SOCKET_DIR/mariadb.pid" ]; then
                  ${mariadbBin}/mariadb-admin -h 127.0.0.1 -P $DB_PORT -u $DB_USER -p$DB_PASSWORD shutdown 2>/dev/null || true
                  kill $(cat "$DB_SOCKET_DIR/mariadb.pid") 2>/dev/null || true
                  rm -f "$DB_SOCKET_DIR/mariadb.pid"
                  echo "✅ MariaDB stopped"
                else
                  echo "❌ MariaDB is not running (no PID file found)"
                fi
              ''
            );
          };

          mariadb-reset = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "reset-mariadb" ''
                export DB_DATA_DIR="$PWD/.dbdata"
                export DB_SOCKET_DIR="/tmp/mariadb_$(id -u)"
                export DB_PORT=${DB_PORT}

                echo "🧹 Resetting MariaDB database..."

                # Stop MariaDB
                if [ -f "$DB_SOCKET_DIR/mariadb.pid" ]; then
                  ${mariadbBin}/mariadb-admin -h 127.0.0.1 -P $DB_PORT -u root shutdown 2>/dev/null || true
                  kill $(cat "$DB_SOCKET_DIR/mariadb.pid") 2>/dev/null || true
                  rm -f "$DB_SOCKET_DIR/mariadb.pid"
                fi

                pkill -f "mariadbd.*datadir=$DB_DATA_DIR" 2>/dev/null || true
                sleep 2

                # Remove data directory
                rm -rf "$DB_DATA_DIR"

                echo "✅ Database reset complete"
                echo "💡 Run 'nix develop' to reinitialize the database"
              ''
            );
          };
        };
      }
    );
}
